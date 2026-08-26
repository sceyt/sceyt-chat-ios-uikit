//
//  AttachmentTransfer.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine
import UIKit.UIImage

let fileProvider = Components.attachmentTransfer.default

open class AttachmentTransfer: DataProvider {
    
    public typealias ProgressBlock = (AttachmentProgress) -> Void
    public typealias CompletionBlock = (AttachmentCompletion) -> Void
    
    private var subscriptions = Set<AnyCancellable>()
    private var tasksQueue = DispatchQueue(label: "com.sceytchat.uikit.attachmentTransfer")
    private var handleTaskQueue = DispatchQueue(label: "com.sceytchat.uikit.task")
    public static var `default` = Components.attachmentTransfer.init()
    
    required public override init() {
        super.init()
    }
    
    @Atomic private var cache = FileProviderCache()
    @Atomic private var uploadCallbackCache = CallbackCache()
    @Atomic private var downloadCallbackCache = CallbackCache()
    @Atomic private var progressCache = ProgressCache()
    @Atomic private var taskGroups = [Int64: [SCTDataSessionTaskInfo]]()
    @Atomic private var inFlightVideoThumbOrigins = Set<String>()
    
    /// Progress reported for an upload the moment its task is created, before any
    /// byte-level callback exists. Small enough to read as "just started" (the UI shows
    /// `Upload.preparing` under 0.01) but > 0, which is what makes the ring visible at all
    /// — `onProgress` ignores non-positive values and the attachment views hide the ring
    /// at 0.
    public static var initialUploadProgress: Double = 0.001

    public private(set) var uploadStopedOperations = [AsyncOperationBlock]()
    public var allTasks: [SCTDataSessionTaskInfo] {
        taskGroups.values.flatMap({ $0 })
    }
    
    open func dataSession(for message: ChatMessage? = nil, forAttachment: ChatMessage.Attachment? = nil) -> SCTDataSession? {
        Components.dataSession
    }
    
    /// Identifies an attachment *for the duration of one transfer*.
    ///
    /// The emitter and the subscriber hold different `ChatMessage.Attachment`
    /// instances of the same attachment — the task captures one when the transfer
    /// starts, the cell rebinds from a fresher copy out of the database. Matching
    /// them requires a discriminator that is populated on both and does not change
    /// while the bytes are moving, which rules out the obvious candidates:
    ///
    /// - `id`   is 0 on the task's copy of an outgoing attachment and non-zero on the
    ///          database's, so leading with it splits one transfer across two keys —
    ///          the emitter publishes to `url…` while the cell listens on `id…`.
    /// - `tid`  is 0 for every incoming attachment (nothing assigns one), so leading
    ///          with it alone collapses all attachments of a message into one bucket.
    ///
    /// Hence: `tid` (stable across an upload) → `url` (present from the start of a
    /// download) → `filePath` (a tid-less upload's local file) → `id` only as a last
    /// resort. This is deliberately *not* `ChatMessage.Attachment.==`, which is
    /// `id`-first and is used for layout diffing elsewhere.
    static func transferIdentity(of attachment: ChatMessage.Attachment) -> String {
        if attachment.tid != 0 {
            return "tid\(attachment.tid)"
        }
        if let url = attachment.url, !url.isEmpty {
            return "url\(url)"
        }
        if let filePath = attachment.filePath, !filePath.isEmpty {
            return "path\((filePath as NSString).lastPathComponent.lowercased())"
        }
        if attachment.id != 0 {
            return "id\(attachment.id)"
        }
        // No tid, url, filePath or id: every such attachment collapses onto one key,
        // so their progress would be delivered to each other's observers.
        logger.error("[Attachment] transferIdentity has nothing to key on — progress delivery will be wrong for \(attachment.description)")
        return "unknown"
    }
    
    /// Statuses that describe a download either in flight or waiting for one, and are
    /// therefore safe to reconcile to `.done` when the bytes turn out to be on disk.
    ///
    /// Deliberately excludes every upload status: an upload has a local file from the
    /// start — that file is what is being sent — so "the file exists" says nothing about
    /// whether it was delivered. `.pending` is shared by both directions, and is included
    /// because that is the one combination the reconcile has always covered.
    static let healableDownloadStatuses: Set<ChatMessage.Attachment.TransferStatus> = [
        .pending, .downloading, .pauseDownloading, .failedDownloading
    ]

    private static func key(message: ChatMessage, attachment: ChatMessage.Attachment) -> String {
        "\(message.id).\(message.tid).\(transferIdentity(of: attachment))"
    }
    
    open func taskFor(message: ChatMessage, attachment: ChatMessage.Attachment) -> SCTDataSessionTaskInfo? {
        if let tasks = taskGroups[message.id != 0 ? Int64(message.id) : message.tid] {
            // Not `==`: that is `id`-first, so a live task holding an id-less copy of
            // this attachment would not be found and the caller would conclude the
            // transfer is dead.
            let identity = Self.transferIdentity(of: attachment)
            return tasks.first(where: { Self.transferIdentity(of: $0.attachment) == identity })
        }
        return nil
    }
    
    open func progress(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        objectIdKey: String = "",
        block: @escaping ProgressBlock,
        completion: CompletionBlock? = nil
    ) {
        let key = Self.key(message: message, attachment: attachment)
        let obj = _Obj(progress: block, completion: completion, idKey: objectIdKey)
        var objs = cache[key, default: []]
        if !objectIdKey.isEmpty,
           let index = objs.firstIndex(where: { $0.idKey == objectIdKey }) {
            // Replace this subscriber's previous registration (a reused cell
            // re-binding the same attachment) instead of accumulating duplicates.
            // Note: the old code never stored idKey on _Obj, so this branch could
            // never match and every rebind appended another closure — each one
            // strongly retaining its captures in this singleton forever.
            objs[index] = obj
        } else {
            objs.append(obj)
        }
        // updateValue bypasses the FileProviderCache subscript, whose setter
        // appends instead of replacing.
        cache.updateValue(objs, forKey: key)
    }
    
    open func currentProgressPercent(message: ChatMessage, attachment: ChatMessage.Attachment) -> Double? {
        progressCache[Self.key(message: message, attachment: attachment)]
    }
    
    open func removeProgressObserver(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        objectIdKey: String = ""
    ) {
        let key = Self.key(message: message, attachment: attachment)
        let existing = cache[key] ?? []
        // Remove only the caller's registration. Dropping the whole bucket silenced
        // every other subscriber for the same attachment — a channel-info cell being
        // deallocated took the open message cell's live progress ring with it.
        if objectIdKey.isEmpty, existing.count > 1 {
            logger.warn("[Attachment] removeProgressObserver called with no objectIdKey — dropping all \(existing.count) observers for \(key), including ones this caller does not own")
        }
        let remaining = objectIdKey.isEmpty ? [] : existing.filter { $0.idKey != objectIdKey }
        // The cached percent belongs to the transfer, not to any one observer: it is
        // what a later rebind reads to restore the ring. Keep it while a task is
        // still running; `didEndTask` clears it when the transfer really is over.
        let liveTask = taskFor(message: message, attachment: attachment) != nil
        if remaining.isEmpty {
            cache[key] = nil
        } else {
            // updateValue, not the subscript: the FileProviderCache setter appends.
            cache.updateValue(remaining, forKey: key)
        }
        if !liveTask {
            progressCache[key] = nil
        }
    }
    
    open func uploadMessageAttachments(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        tasksQueue.async {
            guard let attachments = attachments ?? message.attachments,
                  !attachments.isEmpty
            else {
                completion?(message, nil)
                return
            }
            
            if let dataSession = self.dataSession(for: message) {
                var tasks = [SCTDataSessionTaskInfo]()
                let existTasks = self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid]
                for attachment in attachments {
                    self.repairAttachmentFilePathIfNeeded(attachment, dataSession: dataSession)
                    if let resolvedFilePath = dataSession.getFilePath(attachment: attachment),
                       resolvedFilePath != attachment.filePath {
                        attachment.filePath = resolvedFilePath
                    }
                    guard attachment.filePath != nil
                    else { continue }
                    if existTasks?.contains(where: { $0.attachment.filePath == attachment.filePath }) == true {
                        let key = Self.key(message: message, attachment: attachment)
                        self.uploadCallbackCache[key] = [.init(callback: completion)]
                        continue
                    }
                    
                    attachment.status = .uploading
                    let taskInfo = SCTDataSessionTaskInfo(
                        transferType: .upload,
                        message: message,
                        attachment: attachment
                    )
                    
                    tasks.append(taskInfo)
                    dataSession.upload(
                        attachment: attachment,
                        taskInfo: taskInfo
                    )
                }
                guard !tasks.isEmpty else {
                    completion?(message, AttachmentTransferError.alreadyTransferring)
                    return
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: attachments)
                }
                self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid] = tasks
                self.handle(tasks: tasks, message: message, attachments: attachments) { message, error in
                    self.database.read {
                        var dto: MessageDTO?
                        if let message {
                            if message.id > 0 {
                                dto = MessageDTO.fetch(id: message.id, context: $0)
                            }
                            if dto == nil {
                                dto = MessageDTO.fetch(tid: message.tid, channelId: Int64(message.channelId), context: $0)
                            }
                        }
                        return dto != nil
                    } completion: { result in
                        if let existMessage = try? result.get(),
                            existMessage == true {
                            completion?(message, error)
                        } else {
                            completion?(nil, error)
                        }
                    }
                }
                // Seed a starting progress now that `handle` has installed the event hooks,
                // so the ring shows for the whole pre-transfer window: the checksum
                // round-trip, the image resize / video export, and the wait in the upload
                // queue (serialized, so batch-sent images sit there a while). Without it an
                // image reported nothing until the SDK streamed its first byte — only video
                // seeded itself, from `SCTUploadOperation.startPreparing`.
                for taskInfo in tasks where taskInfo.attachment.status == .uploading {
                    taskInfo.updateProgress(Self.initialUploadProgress)
                }
            } else {
                completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
            }
        }
    }
    
    @discardableResult
    open func downloadMessageAttachmentsIfNeeded(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) -> [ChatMessage.Attachment] {
        guard let attachments = attachments ?? message.attachments,
              !attachments.isEmpty
        else { return [] }

        // Before any status filtering: fetch the small "video_thumb" posters for
        // videos that aren't local yet, so even paused/failed video downloads show
        // a sharp preview instead of the blurred thumbHash.
        downloadVideoThumbnailsIfNeeded(message: message, attachments: attachments)

        var reconciled = [ChatMessage.Attachment]()
        for att in attachments where att.type != "link" {
            let resolvedLocalFilePath = dataSession(for: message)?.getFilePath(attachment: att)
            if let filePath = resolvedLocalFilePath, !filePath.isEmpty {
                guard Self.healableDownloadStatuses.contains(att.status),
                      taskFor(message: message, attachment: att) == nil
                else { continue }
                logger.verbose("[Attachment] reconciling stale \(att.status) to .done, file is on disk \(att.description)")
                att.status = .done
                att.transferProgress = 1
                if att.filePath != filePath {
                    att.filePath = filePath
                }
                reconciled.append(att)

                let key = Self.key(message: message, attachment: att)
                logger.verbose("[Attachment] onCompletion KEY \(key)")
                if let blocks = self.cache[key] {
                    let attachmentCompletion = AttachmentCompletion(
                        message: message,
                        attachment: att,
                        error: nil
                    )
                    blocks.forEach {
                        $0.completion?(attachmentCompletion)
                    }
                }
                AttachmentTransferStatusRelay.default.post(att, status: .done)
            } else if att.status == .done {
                att.status = .pending
                att.transferProgress = 0
                reconciled.append(att)
            }
        }
        if !reconciled.isEmpty {
            database.write {
                $0.update(chatMessage: message, attachments: reconciled)
            }
        }

        let needsToDownloadAttachments = attachments.filter {
            $0.type != "link" &&
            $0.status != .pauseDownloading &&
            $0.status != .failedDownloading &&
            $0.status != .done &&
            dataSession(for: message)?.getFilePath(attachment: $0) == nil
        }
        
        guard !needsToDownloadAttachments.isEmpty else {
            completion?(message, nil)
            return []
        }
        
        downloadMessageAttachments(
            message: message,
            attachments: needsToDownloadAttachments,
            completion: completion)
        return needsToDownloadAttachments
    }
    
    open func downloadMessageAttachments(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        tasksQueue.async {
            guard let attachments = attachments ?? message.attachments
            else {
                logger.verbose("[Attachment] downloadMessageAttachments: nothing to download, message \(message.id) has no attachments")
                completion?(message, nil)
                return
            }
            logger.verbose("[Attachment] downloadMessageAttachments \(attachments.map { $0.description })")
            if let dataSession = self.dataSession(for: message) {
                var tasks = [SCTDataSessionTaskInfo]()
                let existTasks = self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid]
                for (_, attachment) in attachments.enumerated() {
                    guard let url = attachment.url,
                          !url.isEmpty
                    else {
                        // Skipped without a task, so nothing will ever complete or fail
                        // it — it keeps whatever status it has, forever.
                        logger.error("[Attachment] downloadMessageAttachments: skipping attachment with no url, it will never download \(attachment.description)")
                        continue
                    }
                    if existTasks?.contains(where: { $0.attachment.url == attachment.url }) == true || fileProvider.filePath(attachment: attachment) != nil {
                        let key = Self.key(message: message, attachment: attachment)
                        self.downloadCallbackCache[key] = [.init(callback: completion)]
                        logger.verbose("[Attachment] downloadMessageAttachments: Task already exist \(attachments.map { $0.description })")
                        continue
                    }
                    attachment.status = .downloading
                    
                    let taskInfo = SCTDataSessionTaskInfo(
                        transferType: .download,
                        message: message,
                        attachment: attachment
                    )
                    
                    tasks.append(taskInfo)
                    dataSession.download(
                        attachment: attachment,
                        taskInfo: taskInfo
                    )
                }
                guard !tasks.isEmpty else {
                    logger.verbose("[Attachment] downloadMessageAttachments: no new tasks for message \(message.id), every requested attachment is already transferring or on disk")
                    completion?(message, AttachmentTransferError.alreadyTransferring)
                    return
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: attachments)
                }
                if let infos = self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid] {
                    logger.verbose("[Attachment] Download error \(infos.map { $0.attachment.url}) \(message.id)")
                    logger.verbose("[Attachment] Download error new \(tasks.map { $0.attachment.url}) \(tasks.map { $0.message.id})")
                }
                // Merge: overwriting dropped any sibling task still running under this
                // message from the `existTasks` guard consulted on the next rebind.
                let groupKey = message.id != 0 ? Int64(message.id) : message.tid
                self.taskGroups[groupKey] = (self.taskGroups[groupKey] ?? []) + tasks
                self.handle(tasks: tasks, message: message, attachments: attachments, completion: completion)
            } else {
                logger.error("[Attachment] downloadMessageAttachments: Components.dataSession is nil — no transport, nothing will download for message \(message.id)")
                completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
            }
        }
    }
    
    open func stopTransfer(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: ((Bool) -> Void)? = nil) {
        tasksQueue.async {
            guard let task = self.taskFor(message: message, attachment: attachment)
            else {
                switch attachment.status {
                case .downloading:
                    attachment.status = .pauseDownloading
                case .uploading:
                    attachment.status = .pauseUploading
                default:
                    completion?(false)
                    return
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: [attachment])
                }
                AttachmentTransferStatusRelay.default.post(attachment, status: attachment.status)
                completion?(true)
                return
            }
            
            // Matched by transfer identity, not `id`: every attachment of an incoming
            // message has `id == 0` until the server assigns one, so `$0.id == attachment.id`
            // returned whichever attachment came first — pausing the third video paused
            // the first — and when the ids disagreed it matched nothing and silently
            // reported success having changed no status at all.
            let identity = Self.transferIdentity(of: attachment)
            if let attachments = message.attachments,
                let attachment = attachments.first(where: { Self.transferIdentity(of: $0) == identity }) {
                switch task.transferType {
                case .download:
                    attachment.status = .pauseDownloading
                case .upload:
                    attachment.status = .pauseUploading
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: attachments)
                } completion: { _ in
                    task.stop()
                }
                AttachmentTransferStatusRelay.default.post(attachment, status: attachment.status)
                completion?(true)
                return
            }
            logger.error("[Attachment] stopTransfer: no attachment on the message matches \(identity) — status unchanged, the transfer keeps running")
            completion?(true)
        }
    }
    
    open func resumeTransfer(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: ((Bool) -> Void)? = nil) {
            tasksQueue.async {
                guard let task = self.taskFor(message: message, attachment: attachment)
                else {
                    completion?(false)
                    return
                }
                // See `stopTransfer`: `id` is not a usable match for an in-flight transfer.
                let identity = Self.transferIdentity(of: attachment)
                if let attachments = message.attachments,
                   let attachment = attachments.first(where: { Self.transferIdentity(of: $0) == identity }) {
                    switch task.transferType {
                    case .download:
                        attachment.status = .downloading
                    case .upload:
                        attachment.status = .uploading
                    }
                    self.database.write {
                        $0.update(chatMessage: message, attachments: attachments)
                    } completion: { _ in
                        task.resume()
                    }
                    AttachmentTransferStatusRelay.default.post(attachment, status: attachment.status)
                    completion?(true)
                    return
                }
                logger.error("[Attachment] resumeTransfer: no attachment on the message matches \(identity) — status unchanged, the UI will keep showing it paused")
                completion?(true)
                return
            }
        
    }
    
    open func transferStatus(
        message: ChatMessage,
        attachment: ChatMessage.Attachment
    ) -> ChatMessage.Attachment.TransferStatus? {
        guard let task = taskFor(message: message, attachment: attachment)
        else { return nil }
        return task.attachment.status
    }
    
    /// Extracts a poster frame from the video attachment's local file and writes it
    /// as a resized JPEG into the temporary directory. Returns nil when the file is
    /// missing or frame extraction fails — the caller treats that as "no thumbnail".
    open func makeVideoThumbnailFile(for attachment: ChatMessage.Attachment) -> URL? {
        let path = dataSession(forAttachment: attachment)?.getFilePath(attachment: attachment)
            ?? attachment.filePath
        guard let path,
              FileManager.default.fileExists(atPath: path),
              let frame = Components.videoProcessor.copyFrame(url: URL(fileURLWithPath: path)),
              let builder = try? Components.imageBuilder.init(image: frame)
                .resize(max: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.dimensionThreshold),
              let data = builder.jpegData(compressionQuality: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.compressionQuality)
        else { return nil }
        return Components.storage.storeInTemporaryDirectory(
            data: data,
            filename: "video_thumb_\(attachment.tid)",
            ext: "jpg"
        )
    }

    /// After a video upload succeeds, uploads its poster frame through the data
    /// session and merges the returned origin into the attachment metadata under
    /// "video_thumb". Always calls `completion` exactly once; the thumbnail is a
    /// progressive enhancement, so any failure (or a 30s timeout) just sends the
    /// message without it.
    open func attachVideoThumbnailIfNeeded(
        taskInfo: SCTDataSessionTaskInfo,
        message: ChatMessage,
        attachment atch: ChatMessage.Attachment,
        completion: @escaping () -> Void
    ) {
        // Decode the metadata string fresh: the checksum-dedupe path replaces only
        // the string, leaving the eagerly-decoded copy stale — and a dedupe hit on a
        // previously thumbnailed upload already carries "video_thumb" here.
        let decoded = atch.metadata.flatMap { try? ChatMessage.Attachment.Metadata<String>.decode($0) }
        guard taskInfo.transferType == .upload,
              atch.type == "video",
              !message.isViewOnceMessage,
              decoded?.videoThumbnail == nil,
              let dataSession = dataSession(for: message, forAttachment: atch)
        else {
            completion()
            return
        }
        let finish = OneShotBlock(completion)
        handleTaskQueue.asyncAfter(deadline: .now() + 30) {
            finish.fire()
        }
        handleTaskQueue.async { [weak self] in
            guard let self,
                  let fileUrl = self.makeVideoThumbnailFile(for: atch)
            else {
                finish.fire()
                return
            }
            dataSession.uploadAttachmentThumbnail(for: atch, fileUrl: fileUrl) { result in
                defer { try? FileManager.default.removeItem(at: fileUrl) }
                switch result {
                case .success(let origin):
                    var meta = decoded ?? ChatMessage.Attachment.Metadata<String>(thumbnail: "")
                    meta.videoThumbnail = origin
                    atch.updateMetadata(meta.build())
                    logger.verbose("[Attachment] video_thumb uploaded, origin \(origin)")
                case .failure(let error):
                    logger.errorIfNotNil(error, "[Attachment] video_thumb upload failed — sending without it")
                }
                finish.fire()
            }
        }
    }

    /// Local cache path of a downloaded "video_thumb" poster, or nil if not cached.
    open func cachedVideoThumbnailPath(attachment: ChatMessage.Attachment) -> String? {
        guard attachment.type == "video",
              let origin = attachment.imageDecodedMetadata?.videoThumbnail,
              !origin.isEmpty
        else { return nil }
        let path = FileStorage.default.videoThumbnailCachePath(origin: origin)
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    /// Whether `downloadVideoThumbnailsIfNeeded` would actually fetch anything for this
    /// attachment. Answerable from the attachment alone, unlike the fetch itself, which
    /// needs the owner message — attachment list view models call this first so the
    /// overwhelmingly common no-op case costs no message lookup (a database round trip
    /// per bound cell in `ChannelAttachmentListViewModel`).
    open func needsVideoThumbnailDownload(attachment: ChatMessage.Attachment) -> Bool {
        guard attachment.type == "video",
              let origin = attachment.imageDecodedMetadata?.videoThumbnail,
              !origin.isEmpty,
              cachedVideoThumbnailPath(attachment: attachment) == nil,
              filePath(attachment: attachment) == nil,
              !inFlightVideoThumbOrigins.contains(origin)
        else { return false }
        return true
    }

    /// Downloads the "video_thumb" poster for video attachments whose video file is
    /// not local yet, so the receiver can show a sharp preview while the (much
    /// larger) video is still downloading. Failures are dropped silently and
    /// retried on the next cell bind.
    open func downloadVideoThumbnailsIfNeeded(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil
    ) {
        guard !message.isViewOnceMessage,
              let attachments = attachments ?? message.attachments,
              let dataSession = dataSession(for: message)
        else { return }
        for atch in attachments where atch.type == "video" {
            guard let origin = atch.imageDecodedMetadata?.videoThumbnail,
                  !origin.isEmpty,
                  dataSession.getFilePath(attachment: atch) == nil,
                  cachedVideoThumbnailPath(attachment: atch) == nil,
                  !inFlightVideoThumbOrigins.contains(origin)
            else { continue }
            inFlightVideoThumbOrigins.insert(origin)
            dataSession.downloadAttachmentThumbnail(for: atch, origin: origin) { [weak self] result in
                guard let self else { return }
                self.inFlightVideoThumbOrigins.remove(origin)
                guard case .success(let localUrl) = result else {
                    if case .failure(let error) = result {
                        logger.errorIfNotNil(error, "[Attachment] video_thumb download failed, origin \(origin)")
                    }
                    return
                }
                let destination = URL(fileURLWithPath: FileStorage.default.videoThumbnailCachePath(origin: origin))
                do {
                    let data = try Data(contentsOf: localUrl)
                    // Atomic write so a concurrent loadThumbnail never observes a
                    // partially written JPEG (same pattern as SCTSession.thumbnailFile).
                    try data.write(to: destination, options: .atomic)
                    try? FileManager.default.removeItem(at: localUrl)
                } catch {
                    logger.errorIfNotNil(error, "[Attachment] video_thumb store failed, origin \(origin)")
                    return
                }
                DispatchQueue.main.async {
                    if let image = UIImage(contentsOfFile: destination.path) {
                        AttachmentSharpThumbnailRelay.default.post(atch, image: image)
                    }
                }
            }
        }
    }

    private func handle(
        tasks: [SCTDataSessionTaskInfo],
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        func onProgress( _ progress: Double, taskInfo: SCTDataSessionTaskInfo) {
            guard progress > 0
            else { return }
            let key = Self.key(message: taskInfo.message, attachment: taskInfo.attachment)
            let attachmentProgress = AttachmentProgress(
                message: taskInfo.message,
                attachment: taskInfo.attachment,
                progress: progress
            )
            logger.verbose("[Attachment] onProgress KEY \(key)")
            if let blocks = self.cache[key], !blocks.isEmpty {
                blocks.forEach {
                    $0.progress?(attachmentProgress)
                }
            } else {
                // The transfer is running but nothing is listening on this key. Either
                // no view is on screen for it, or the emitter and the subscriber
                // disagree on the attachment's identity — the latter shows up as a ring
                // frozen at its bind-time floor until the download completes.
                logger.warn("[Attachment] onProgress has no observers for KEY \(key) — progress \(progress) will not be rendered \(taskInfo.attachment.description)")
            }
            self.progressCache[key] = progress
        }
        
        func onCompletion(
            taskInfo: SCTDataSessionTaskInfo,
            attachment: ChatMessage.Attachment,
            error: Error? = nil
        ) {
            let key = Self.key(message: taskInfo.message, attachment: taskInfo.attachment)
            logger.verbose("[Attachment] onCompletion KEY \(key)")
            if let blocks = self.cache[key] {
                let attachmentCompletion = AttachmentCompletion(
                    message: message,
                    attachment: attachment,
                    error: error
                )
                blocks.forEach {
                    $0.completion?(attachmentCompletion)
                }
            }
        }
        
        for (index, taskInfo) in tasks.enumerated() {
            taskInfo.onEvent = { [weak self, index] event in
                    guard let self else { return }
                    switch event {
                    case .updateProgress(let progress):
                        onProgress(progress, taskInfo: taskInfo)
                    case .updateLocalFileURL(let url, let filePath):
                        logger.verbose("[Attachment] Handle updateLocalFileURL \(url)")
                        if attachments.indices.contains(index) {
                            let atch = attachments[index]
                            logger.verbose("[Attachment] Handle updateLocalFileURL found \(String(describing: atch.url))")
                            if let builder = Components.imageBuilder.init(imageUrl: url) {
                                if let decodedMetadata = atch.imageDecodedMetadata {
                                    atch.metadata =
                                    ChatMessage.Attachment.Metadata(
                                        width: Int(builder.imageSize.width),
                                        height: Int(builder.imageSize.height),
                                        thumbnail: decodedMetadata.thumbnail,
                                        duration: decodedMetadata.duration,
                                        description: decodedMetadata.description,
                                        imageUrl: decodedMetadata.imageUrl,
                                        thumbnailUrl: decodedMetadata.thumbnailUrl,
                                        hideLinkDetails: decodedMetadata.hideLinkDetails,
                                        videoThumbnail: decodedMetadata.videoThumbnail
                                    ).build()
                                } else if let decodedMetadata = atch.voiceDecodedMetadata {
                                    atch.metadata =
                                    ChatMessage.Attachment.Metadata(
                                        width: Int(builder.imageSize.width),
                                        height: Int(builder.imageSize.height),
                                        thumbnail: decodedMetadata.thumbnail,
                                        duration: decodedMetadata.duration,
                                        description: decodedMetadata.description,
                                        imageUrl: decodedMetadata.imageUrl,
                                        thumbnailUrl: decodedMetadata.thumbnailUrl,
                                        hideLinkDetails: decodedMetadata.hideLinkDetails,
                                        videoThumbnail: decodedMetadata.videoThumbnail
                                    ).build()
                                }
                            }
                            atch.name = url.lastPathComponent
                            atch.filePath = url.path
                            let fileSize = Components.storage.sizeOfItem(at: url)
                            if fileSize > 0 {
                                atch.uploadedFileSize = fileSize
                            }
                            if taskInfo.transferType == .download, fileSize > 0 {
                                atch.transferProgress = 1
                                atch.status = .done
                            }
                            taskInfo.attachment = atch
                            self.database.write {
                                if let filePath {
                                    logger.verbose("[Attachment] Handle updateLocalFileURL file by filePath \(String(describing: atch.url))")
                                    $0.updateAttachment(with: filePath, chatMessage: message, attachment: atch)
                                } else {
                                    logger.verbose("[Attachment] Handle updateLocalFileURL file by [] \(String(describing: atch.url))")
                                    $0.update(chatMessage: message, attachments: [atch])
                                }
                            }
                        }
                    case .successURL(let url):
                        logger.verbose("[Attachment] Handle successURL  \(url)")
                        finishSuccess(uri: url.absoluteString, taskInfo: taskInfo, index: index)
                    case .successURI(let uri):
                        logger.verbose("[Attachment] Handle successURI  \(uri)")
                        finishSuccess(uri: uri, taskInfo: taskInfo, index: index)
                    case .failure(let error):
                        logger.errorIfNotNil(error, "[Attachment] transfer")
                        if attachments.indices.contains(index) {
                            let atch = attachments[index]
                            logger.verbose("[Attachment] Handle failure  found \(String(describing: atch.url))")
                            switch taskInfo.transferType {
                            case .download:
                                if atch.status != .pauseDownloading {
                                    atch.status = .failedDownloading
                                }
                            case .upload:
                                if atch.status != .pauseUploading {
                                    atch.status = .failedUploading
                                }
                            }
                            onCompletion(taskInfo: taskInfo, attachment: atch, error: error)
                            AttachmentTransferStatusRelay.default.post(atch, status: atch.status)
                        }
                        logger.errorIfNotNil(error, "[Attachment] receive failure")
                        didEndTask(taskInfo: taskInfo, error: error)
                    }
                }
        }
        
        func finishSuccess(uri: String, taskInfo: SCTDataSessionTaskInfo, index: Int) {
            guard attachments.indices.contains(index) else {
                logger.verbose("[Attachment] receive success \(uri)")
                didEndTask(taskInfo: taskInfo, error: nil)
                return
            }
            let atch = attachments[index]
            logger.verbose("[Attachment] Handle success found \(String(describing: atch.url))")
            // For a just-uploaded video, upload its poster frame too before completing,
            // so the merged "video_thumb" metadata is persisted by didEndTask and rides
            // the wire message the sender builds from this attachment.
            attachVideoThumbnailIfNeeded(taskInfo: taskInfo, message: message, attachment: atch) {
                atch.url = uri
                atch.transferProgress = 1
                atch.status = .done
                onCompletion(taskInfo: taskInfo, attachment: atch)
                AttachmentTransferStatusRelay.default.post(atch, status: .done)
                logger.verbose("[Attachment] receive success \(uri)")
                didEndTask(taskInfo: taskInfo, error: nil)
            }
        }

        func didEndTask(taskInfo: SCTDataSessionTaskInfo, error: Error?) {
            let key = Self.key(message: taskInfo.message, attachment: taskInfo.attachment)
            let groupKey = message.id != 0 ? Int64(message.id) : message.tid
            // The task is over — no progress/completion event will ever fire for this
            // key again. Drop the cached percent so a later cell rebind that still
            // reads a stale `.downloading` status can't restore a progress ring that
            // nothing would ever hide.
            self.progressCache[key] = nil
            var storedMessage: ChatMessage?
            self.database.write(resultQueue: .global()) {
                storedMessage = $0.update(chatMessage: message, attachments: attachments)?.convert()
                for attachment in attachments where attachment.url != nil {
                    $0.updateChecksum(data: attachment.url!, messageTid: message.tid, attachmentTid: attachment.tid)
                }
            } completion: { _ in
                completion?(storedMessage ?? message, error)
                switch taskInfo.transferType {
                case .upload:
                    if let callbacks = self.uploadCallbackCache[key] {
                        for callback in callbacks {
                            logger.verbose("[Attachment] Handle didEndTask  uploadCallbackCache \(callback)")
                            callback.callback?(storedMessage ?? message, error)
                        }
                        self.uploadCallbackCache[key] = nil
                    }
                case .download:
                    if let callbacks = self.downloadCallbackCache[key] {
                        for callback in callbacks {

                            logger.verbose("[Attachment] Handle didEndTask  downloadCallbackCache \(callback)")
                            callback.callback?(storedMessage ?? message, error)
                        }
                        self.downloadCallbackCache[key] = nil
                    }
                }
            }
            if let taskInfos = self.taskGroups[groupKey] {
                logger.verbose("[Attachment] Handle didEndTask  taskInfos \(taskInfos.map { $0.attachment.url})")
                // Only this task is over. Clearing the whole group left the message's
                // other attachments with no entry to guard against, so the next cell
                // rebind started a second download for bytes already in flight.
                let survivors = taskInfos.filter { $0 !== taskInfo }
                self.taskGroups[groupKey] = survivors.isEmpty ? nil : survivors
            }
            
        }
    }
    
    func filePath(attachment: ChatMessage.Attachment) -> String? {
        guard let dataSession = dataSession(forAttachment: attachment)
        else {
            if attachment.filePath != nil {
                return attachment.filePath
            } else if let url = attachment.url {
                return Components.storage.filePath(for: url)
            }
            return nil
        }
        return dataSession.getFilePath(attachment: attachment)
    }
    
    private func repairAttachmentFilePathIfNeeded(_ attachment: ChatMessage.Attachment, dataSession: SCTDataSession) {
        guard let currentPath = attachment.filePath,
              !FileManager.default.fileExists(atPath: currentPath)
        else { return }
        
        if let recoveredPath = dataSession.getFilePath(attachment: attachment),
           FileManager.default.fileExists(atPath: recoveredPath) {
            attachment.filePath = recoveredPath
            return
        }

        if let temporaryPath = recoverTemporaryPath(for: attachment) {
            attachment.filePath = temporaryPath
        }
    }

    private func recoverTemporaryPath(for attachment: ChatMessage.Attachment) -> String? {
        let fileName = attachment.name ?? (attachment.filePath as NSString?)?.lastPathComponent
        guard let fileName, !fileName.isEmpty else { return nil }
        
        let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent(fileName).path
        guard FileManager.default.fileExists(atPath: tmpPath) else { return nil }
        return tmpPath
    }

    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? {
        guard let dataSession = dataSession(forAttachment: attachment)
        else { return nil }
        return dataSession.thumbnailFile(for: attachment, preferred: size)
    }
}

extension AttachmentTransfer {
    public class AttachmentProgress {
        public let message: ChatMessage
        public let attachment: ChatMessage.Attachment
        public let progress: Double
        
        init(message: ChatMessage,
             attachment: ChatMessage.Attachment,
             progress: Double) {
            self.message = message
            self.attachment = attachment
            self.progress = progress
        }
    }
    
    public class AttachmentCompletion {
        public let message: ChatMessage
        public let attachment: ChatMessage.Attachment
        public let error: Error?
        
        init(message: ChatMessage,
             attachment: ChatMessage.Attachment,
             error: Error? = nil
        ) {
            self.message = message
            self.attachment = attachment
            self.error = error
        }
        
    }
}

enum AttachmentTransferError: Error {
    case alreadyTransferring
    case externalTransferrerNotImplemented
}

/// Runs the wrapped block at most once, from whichever caller fires first
/// (e.g. a completion callback racing its timeout fallback).
private final class OneShotBlock {
    private let lock = NSLock()
    private var block: (() -> Void)?

    init(_ block: @escaping () -> Void) {
        self.block = block
    }

    func fire() {
        lock.lock()
        let block = self.block
        self.block = nil
        lock.unlock()
        block?()
    }
}


private struct _Obj {
    var progress: AttachmentTransfer.ProgressBlock?
    var completion: AttachmentTransfer.CompletionBlock?
    var idKey: String = ""
}

private struct _CallBack {
    var callback: ((ChatMessage?, Error?) -> Void)? = nil
}

private typealias FileProviderCache = [String: [_Obj]]
private typealias ProgressCache = [String: Double]
private typealias CallbackCache = [String: [_CallBack]]

private extension FileProviderCache {
    
    subscript(key: String) -> [_Obj] {
        get {
            self[key] ?? []
        }
        set {
            if self[key] == nil {
                self[key] = []
            }
            self[key] = self[key]?.filter { $0.progress != nil }
            self[key]?.append(contentsOf: newValue)
        }
    }
}

private extension CallbackCache {
    
    subscript(key: String) -> [_CallBack] {
        get {
            self[key] ?? []
        }
        set {
            if self[key] == nil {
                self[key] = []
            }
            self[key] = self[key]?.filter { $0.callback != nil }
            self[key]?.append(contentsOf: newValue)
        }
    }
}

public extension AttachmentTransfer {

    /// A stable identity for one progress subscriber, for `objectIdKey`.
    ///
    /// Derived from the observing object, not from the attachment: an attachment's
    /// `description` embeds `filePath`, which is `nil` while downloading and set
    /// once the bytes land, so a key built from it changes underneath the observer
    /// and neither the replace-on-rebind nor the scoped removal can match it.
    static func observerKey(for object: AnyObject, prefix: String) -> String {
        prefix + "." + String(UInt(bitPattern: ObjectIdentifier(object).hashValue), radix: 16)
    }
}
