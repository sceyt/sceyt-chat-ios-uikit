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
    /// Transfer keys already reported as having no progress observer, so the warning is
    /// emitted once per transfer instead of once per byte-chunk.
    @Atomic private var unobservedProgressKeys = Set<String>()
    
    /// Progress reported for an upload the moment its task is created, before any
    /// byte-level callback exists. Small enough to read as "just started" (the UI shows
    /// `Upload.preparing` under 0.01) but > 0, which is what makes the ring visible at all
    /// — `onProgress` ignores non-positive values and the attachment views hide the ring
    /// at 0.
    public static var initialUploadProgress: Double = 0.001

    /// Whether the client currently has no connection to the server. An upload failure
    /// raised in this state says nothing about the file or the server — only that there is
    /// nothing to send over — so it is treated as "wait", not as "failed".
    open class var isOffline: Bool {
        SceytChatUIKit.shared.chatClient.connectionState != .connected
    }

    /// How long a video's poster upload may take before the video goes out without it. A test
    /// seam: 30 s in production.
    var videoThumbnailTimeout: TimeInterval = 30

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
        logger.error("[Attachment] transferIdentity has nothing to key on — progress delivery will be wrong for \(attachment.transferLogDescription)")
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

    /// Image files already found readable, so a cell bind does not reread a header it has read.
    nonisolated(unsafe) private static let readableImageFiles = NSCache<NSString, NSNumber>()

    /// Paths already removed once this session. A file that is still unreadable after its
    /// re-download is a real file ImageIO cannot decode, not a leftover, and removing it again
    /// would download it on every cell bind.
    nonisolated(unsafe) private static let discardedImageFiles = NSCache<NSString, NSNumber>()

    /// Whether the local file of an image attachment can stand in for its download.
    ///
    /// A failed download can leave something other than the image at the destination — S3
    /// writes its error body there on a 404. Read as "the file is on disk", that marked the
    /// attachment `.done` with bytes nothing can show, and it was never downloaded again. Such a
    /// file is removed so the attachment counts as not downloaded.
    ///
    /// Only finished, received images are judged: a live transfer still owns its file, and an
    /// unsent attachment's file is the user's source, which is never deleted.
    func keepsLocalFile(
        _ path: String,
        of attachment: ChatMessage.Attachment,
        message: ChatMessage
    ) -> Bool {
        guard attachment.type == "image",
              !attachment.isPendingUpload,
              taskFor(message: message, attachment: attachment) == nil
        else { return true }
        if Self.readableImageFiles.object(forKey: path as NSString) != nil {
            return true
        }
        guard SCTSession.isCompleteImageFile(at: path) else {
            guard Self.discardedImageFiles.object(forKey: path as NSString) == nil else {
                logger.error("[Attachment] keeping \(path): still not a readable image after a re-download \(attachment.transferLogDescription)")
                return true
            }
            Self.discardedImageFiles.setObject(true, forKey: path as NSString)
            logger.error("[Attachment] removing \(path): not a readable image, so the download is not done \(attachment.transferLogDescription)")
            try? FileManager.default.removeItem(atPath: path)
            if attachment.filePath == path {
                attachment.filePath = nil
            }
            return false
        }
        Self.readableImageFiles.setObject(true, forKey: path as NSString)
        return true
    }

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
            logger.warn("[Attachment] removeProgressObserver called with no objectIdKey — dropping all \(existing.count) observers for \(TransferLog.redact(key)), including ones this caller does not own")
        }
        let remaining = objectIdKey.isEmpty ? [] : existing.filter { $0.idKey != objectIdKey }
        // The cached percent belongs to the transfer, not to any one observer: it is
        // what a later rebind reads to restore the ring. Keep it while a task is
        // still running; `didEndTask` clears it when the transfer really is over.
        let liveTask = taskFor(message: message, attachment: attachment) != nil
        if remaining.isEmpty {
            cache[key] = nil
        } else {
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
            self.startUploads(message: message, attachments: attachments, completion: completion)
        }
    }

    /// The operation id `dataSession` will use for `attachment`, assigned to the task before
    /// the session sees it, so every layer's lines carry the same `xfer=`.
    static func assignOperationId(to taskInfo: SCTDataSessionTaskInfo, dataSession: SCTDataSession) {
        guard let session = dataSession as? TransportDataSession else { return }
        switch taskInfo.transferType {
        case .upload:
            taskInfo.assign(operationId: session.uploadOperationId(for: taskInfo.attachment))
        case .download:
            taskInfo.assign(operationId: session.downloadOperationId(for: taskInfo.attachment))
        }
    }

    private func startUploads(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)?
    ) {
            if let dataSession = self.dataSession(for: message) {
                let groupKey = message.id != 0 ? Int64(message.id) : message.tid
                var tasks = [SCTDataSessionTaskInfo]()
                var starts = [SCTDataSessionTaskInfo]()
                var rejected = [(SCTDataSessionTaskInfo, Error)]()
                let existTasks = self.taskGroups[groupKey]
                for attachment in attachments {
                    self.repairAttachmentFilePathIfNeeded(attachment, dataSession: dataSession)
                    if let resolvedFilePath = dataSession.getFilePath(attachment: attachment),
                       resolvedFilePath != attachment.filePath {
                        attachment.filePath = resolvedFilePath
                    }
                    // A task that already ended (a cancelled one included) does not count: a
                    // new upload of its file is a new upload.
                    if let filePath = attachment.filePath,
                       let running = existTasks?.first(where: { !$0.isTerminal && $0.attachment.filePath == filePath }) {
                        let key = Self.key(message: message, attachment: attachment)
                        // Appended: an earlier caller waiting on the same upload keeps its
                        // completion (`[key] = …` is the Dictionary setter, which replaces).
                        if let completion {
                            self._uploadCallbackCache.mutate { $0[key, default: []].append(.init(callback: completion)) }
                        }
                        logger.info("[Attachment] \(running.logTag) upload already running for this file, waiting for it \(attachment.transferLogDescription)")
                        continue
                    }
                    let taskInfo = SCTDataSessionTaskInfo(
                        transferType: .upload,
                        message: message,
                        attachment: attachment
                    )
                    Self.assignOperationId(to: taskInfo, dataSession: dataSession)
                    tasks.append(taskInfo)
                    let tag = taskInfo.logTag
                    guard attachment.filePath != nil else {
                        // Failed, not skipped: without a task nothing would ever change its status.
                        logger.debug("[Attachment] \(tag) upload has no local file (source deleted?): failing it (missingSourceFile) \(attachment.transferLogDescription)")
                        rejected.append((taskInfo, TransportDataSessionError.missingSourceFile))
                        continue
                    }
                    attachment.status = .uploading
                    let setup = TransferLog.with(taskInfo.logContext) {
                        self.uploadEncryption(message: message, attachments: [attachment])[ObjectIdentifier(attachment)]
                    }
                    if let setup {
                        // Fail closed: an attachment that must be encrypted never reaches a
                        // session that would upload it as plaintext.
                        if let error = Self.apply(setup, to: taskInfo, dataSession: dataSession) {
                            logger.debug("[Encryption] \(tag) upload rejected before start (fail closed): \(TransferLog.describe(error)) session=\(type(of: dataSession))")
                            rejected.append((taskInfo, error))
                            continue
                        }
                    }
                    logger.info("[Attachment] \(tag) upload start type=\(taskInfo.encryption == .required ? "encrypted" : "plain") size=\(TransferLog.size(path: attachment.filePath)) session=\(type(of: dataSession)) \(attachment.transferLogDescription)")
                    starts.append(taskInfo)
                }
                guard !tasks.isEmpty else {
                    logger.info("[Attachment] upload: no new task for message \(message.id)/\(message.tid) channel=\(message.channelId), every attachment is already uploading")
                    completion?(message, AttachmentTransferError.alreadyTransferring)
                    return
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: attachments)
                }
                // Merged, like `startDownloads`: overwriting dropped the tasks an earlier call
                // still runs for this message, so the `existTasks` guard no longer saw them and
                // their pause / resume / progress lookups found nothing. A rejected task never
                // joins: it ends below, before any session sees it.
                let rejectedTasks = Set(rejected.map { ObjectIdentifier($0.0) })
                let started = tasks.filter { !rejectedTasks.contains(ObjectIdentifier($0)) }
                if !started.isEmpty {
                    // One locked step: `didEndTask` removes tasks from other threads.
                    self._taskGroups.mutate { $0[groupKey, default: []].append(contentsOf: started) }
                }
                // The hooks go in before any session sees a task: an event it reports at once
                // (a fast failure) is never lost.
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
                for (taskInfo, error) in rejected {
                    taskInfo.failure(error: error)
                }
                // Seed a starting progress, so the ring shows for the whole pre-transfer
                // window: the checksum round-trip, the image resize / video export, and the
                // wait in the upload queue (serialized, so batch-sent images sit there a while).
                for taskInfo in starts where taskInfo.attachment.status == .uploading {
                    taskInfo.updateProgress(Self.initialUploadProgress)
                }
                for taskInfo in starts {
                    dataSession.upload(attachment: taskInfo.attachment, taskInfo: taskInfo)
                }
            } else {
                logger.error("[Attachment] upload: no data session, nothing uploads for message \(message.id)/\(message.tid) channel=\(message.channelId)")
                completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
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
            if let filePath = resolvedLocalFilePath, !filePath.isEmpty,
               keepsLocalFile(filePath, of: att, message: message) {
                guard Self.healableDownloadStatuses.contains(att.status),
                      // `.pending` is shared by both directions and this rule reads a local
                      // file as proof the transfer finished — true for a download, false for
                      // an upload whose source file is exactly what has not been sent yet.
                      // Without this an outgoing attachment waiting to upload is marked
                      // `.done` the first time its cell is displayed, which takes the loader
                      // off screen and makes an unsent photo look delivered.
                      !att.isPendingUpload,
                      taskFor(message: message, attachment: att) == nil
                else { continue }
                logger.verbose("[Attachment] reconciling stale \(att.status) to .done, file is on disk \(att.transferLogDescription)")
                att.status = .done
                att.transferProgress = 1
                if att.filePath != filePath {
                    att.filePath = filePath
                }
                reconciled.append(att)

                let key = Self.key(message: message, attachment: att)
                logger.verbose("[Attachment] onCompletion KEY \(TransferLog.redact(key))")
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
            self.startDownloads(message: message, attachments: attachments, completion: completion)
        }
    }

    private func startDownloads(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)?
    ) {
            if let dataSession = self.dataSession(for: message) {
                let groupKey = message.id != 0 ? Int64(message.id) : message.tid
                var tasks = [SCTDataSessionTaskInfo]()
                var starts = [SCTDataSessionTaskInfo]()
                var rejected = [(SCTDataSessionTaskInfo, Error)]()
                let existTasks = self.taskGroups[groupKey]
                for attachment in attachments {
                    let taskInfo = SCTDataSessionTaskInfo(
                        transferType: .download,
                        message: message,
                        attachment: attachment
                    )
                    Self.assignOperationId(to: taskInfo, dataSession: dataSession)
                    let tag = taskInfo.logTag
                    guard let url = attachment.url,
                          !url.isEmpty
                    else {
                        // Skipped without a task, so nothing will ever complete or fail
                        // it — it keeps whatever status it has, forever.
                        logger.error("[Attachment] \(tag) download skipped: the attachment has no url, it will never download \(attachment.transferLogDescription)")
                        continue
                    }
                    let running = existTasks?.contains(where: { !$0.isTerminal && $0.attachment.url == attachment.url }) == true
                    if running || fileProvider.filePath(attachment: attachment) != nil {
                        let key = Self.key(message: message, attachment: attachment)
                        if let completion {
                            self._downloadCallbackCache.mutate { $0[key, default: []].append(.init(callback: completion)) }
                        }
                        logger.verbose("[Attachment] \(tag) download: \(running ? "task already exists" : "file already on disk"), waiting for it")
                        continue
                    }
                    attachment.status = .downloading
                    tasks.append(taskInfo)
                    let setup = TransferLog.with(taskInfo.logContext) {
                        self.downloadEncryption(attachments: [attachment])[ObjectIdentifier(attachment)]
                    }
                    if let setup {
                        // A malformed encryption field or a session that would store the
                        // ciphertext as the file: fail before fetching anything.
                        if let error = Self.apply(setup, to: taskInfo, dataSession: dataSession) {
                            logger.debug("[Encryption] \(tag) download rejected before fetching (fail closed): \(TransferLog.describe(error)) session=\(type(of: dataSession))")
                            rejected.append((taskInfo, error))
                            continue
                        }
                    }
                    logger.info("[Attachment] \(tag) download start type=\(taskInfo.encryption == .required ? "encrypted" : "plain") size=\(attachment.uploadedFileSize) url=\(TransferLog.redact(attachment.url)) session=\(type(of: dataSession)) \(attachment.transferLogDescription)")
                    starts.append(taskInfo)
                }
                guard !tasks.isEmpty else {
                    logger.verbose("[Attachment] download: no new task for message \(message.id)/\(message.tid) channel=\(message.channelId), every requested attachment is already transferring or on disk")
                    completion?(message, AttachmentTransferError.alreadyTransferring)
                    return
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: attachments)
                }
                // Merge: overwriting dropped any sibling task still running under this
                // message from the `existTasks` guard consulted on the next rebind.
                self._taskGroups.mutate { $0[groupKey, default: []].append(contentsOf: tasks) }
                // The hooks go in before any session sees a task: an event it reports at once
                // (a fast failure) is never lost.
                self.handle(tasks: tasks, message: message, attachments: attachments, completion: completion)
                for (taskInfo, error) in rejected {
                    taskInfo.failure(error: error)
                }
                for taskInfo in starts {
                    dataSession.download(attachment: taskInfo.attachment, taskInfo: taskInfo)
                }
            } else {
                logger.error("[Attachment] download: no data session, nothing will download for message \(message.id)/\(message.tid) channel=\(message.channelId)")
                completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
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
                case .pending where attachment.isPendingUpload:
                    // A queued upload: no task yet (waiting on the upload queue, or waiting
                    // for a connection after an offline attempt). The pause still has to
                    // stick — `SyncService` skips resending a message whose attachments are
                    // paused, which is what keeps it from going out on the next connect.
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
            // The bytes already landed and the task is only finishing (video poster upload,
            // persisting). Pausing now would persist and relay `.pauseUploading` over the
            // `.done` that is about to be written — the upload icon over a sent file.
            guard !task.isTransferFinished else {
                completion?(false)
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
            logger.error("[Attachment] stopTransfer: no attachment on the message matches \(TransferLog.redact(identity)) — status unchanged, the transfer keeps running")
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
                // Already delivered and finishing: nothing to resume, but it is not stalled
                // either — reporting `false` would make callers resend the message.
                guard !task.isTransferFinished else {
                    completion?(true)
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
                logger.error("[Attachment] resumeTransfer: no attachment on the message matches \(TransferLog.redact(identity)) — status unchanged, the UI will keep showing it paused")
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
        handleTaskQueue.asyncAfter(deadline: .now() + videoThumbnailTimeout) {
            if finish.fire() {
                logger.warn("[Attachment] \(taskInfo.logTag) video_thumb timed out after 30 s, sending without it")
            }
        }
        handleTaskQueue.async { [weak self] in
            guard let self,
                  let fileUrl = self.makeVideoThumbnailFile(for: atch)
            else {
                logger.warn("[Attachment] \(taskInfo.logTag) video_thumb: no poster frame could be made, sending without it")
                finish.fire()
                return
            }
            // A dedupe hit can reuse an encrypted object even for a plain send: its poster
            // must then be encrypted too, or the receiver could not show it.
            if taskInfo.encryption == .required || atch.isEncrypted {
                self.uploadEncryptedVideoThumbnail(fileUrl, taskInfo: taskInfo, attachment: atch, decoded: decoded, dataSession: dataSession, finish: finish)
                return
            }
            let tag = taskInfo.logTag
            TransferLog.with(taskInfo.logContext) {
                dataSession.uploadAttachmentThumbnail(for: atch, fileUrl: fileUrl) { result in
                    defer { TransferLog.remove(fileUrl, what: "the poster frame", context: "[Attachment] \(tag) video_thumb") }
                    switch result {
                    case .success(let origin):
                        var meta = decoded ?? ChatMessage.Attachment.Metadata<String>(thumbnail: "")
                        meta.videoThumbnail = origin
                        Self.updateMetadata(of: atch, rebuiltFrom: meta)
                        logger.verbose("[Attachment] \(tag) video_thumb uploaded, origin \(TransferLog.redact(origin))")
                    case .failure(let error):
                        logger.warn("[Attachment] \(tag) video_thumb upload failed, sending without it: \(TransferLog.describe(error))")
                    }
                    finish.fire()
                }
            }
        }
    }

    /// Sets `atch`'s metadata to `meta`, keeping the `enc` the typed model does not know: a
    /// dedupe hit's metadata already carries the reused object's key.
    static func updateMetadata(of atch: ChatMessage.Attachment, rebuiltFrom meta: ChatMessage.Attachment.Metadata<String>) {
        atch.updateMetadata(ChatMessage.Attachment.metadata(meta.build(), preservingEncryptionFrom: atch.metadata))
    }

    /// The `enc` an upload's metadata must carry, or nil when it has none to write: the
    /// uploaded object's key with the poster's rendition, or, for a dedupe hit (nothing was
    /// uploaded, the reused object's `enc` is already in the metadata), that `enc` with the
    /// rendition of a poster uploaded for it.
    static func uploadEncryption(of taskInfo: SCTDataSessionTaskInfo, attachment atch: ChatMessage.Attachment) -> AttachmentEncryption? {
        let renditions = taskInfo.thumbnailRendition.map { [$0] } ?? []
        if let info = taskInfo.uploadedEncryption {
            return AttachmentEncryption(info: info, renditions: renditions)
        }
        guard let rendition = taskInfo.thumbnailRendition, let reused = atch.encryption else { return nil }
        return AttachmentEncryption(
            algorithm: reused.algorithm,
            attachmentId: reused.attachmentId,
            key: reused.key,
            renditions: reused.renditions.filter { $0.role != rendition.role } + [rendition]
        )
    }

    /// The poster of an encrypted video, encrypted under its own key: a plaintext poster would
    /// show the video's content. "video_thumb" and its `enc.renditions` entry are set together,
    /// or neither is: the video then goes out without a poster.
    private func uploadEncryptedVideoThumbnail(
        _ fileUrl: URL,
        taskInfo: SCTDataSessionTaskInfo,
        attachment atch: ChatMessage.Attachment,
        decoded: ChatMessage.Attachment.Metadata<String>?,
        dataSession: SCTDataSession,
        finish: OneShotBlock
    ) {
        let context = taskInfo.logContext
        let tag = taskInfo.logTag
        Task {
            let ciphertext = fileUrl.deletingPathExtension().appendingPathExtension("enc")
            let info: EncryptedFileInfo
            do {
                info = try await TransferLog.$current.withValue(context) {
                    try await Components.fileEncryption.encrypt(file: fileUrl, to: ciphertext)
                }
            } catch {
                TransferLog.remove(fileUrl, what: "the poster frame", context: "[Encryption] \(tag) video_thumb")
                logger.warn("[Encryption] \(tag) video_thumb encryption failed, sending without it: \(TransferLog.describe(error))")
                finish.fire()
                return
            }
            TransferLog.remove(fileUrl, what: "the plaintext poster frame", context: "[Encryption] \(tag) video_thumb")
            uploadEncryptedVideoThumbnail(ciphertext, info: info, taskInfo: taskInfo, attachment: atch, decoded: decoded, dataSession: dataSession, finish: finish)
        }
    }

    private func uploadEncryptedVideoThumbnail(
        _ ciphertext: URL,
        info: EncryptedFileInfo,
        taskInfo: SCTDataSessionTaskInfo,
        attachment atch: ChatMessage.Attachment,
        decoded: ChatMessage.Attachment.Metadata<String>?,
        dataSession: SCTDataSession,
        finish: OneShotBlock
    ) {
        let tag = taskInfo.logTag
        TransferLog.with(taskInfo.logContext) {
        dataSession.uploadAttachmentThumbnail(for: atch, fileUrl: ciphertext) { result in
            defer { TransferLog.remove(ciphertext, what: "the encrypted poster", context: "[Encryption] \(tag) video_thumb") }
            switch result {
            case .success(let origin):
                let applied = finish.fire {
                    var meta = decoded ?? ChatMessage.Attachment.Metadata<String>(thumbnail: "")
                    meta.videoThumbnail = origin
                    Self.updateMetadata(of: atch, rebuiltFrom: meta)
                    taskInfo.thumbnailRendition = AttachmentEncryption.Rendition(role: AttachmentEncryption.Rendition.thumbnailRole, info: info)
                    logger.verbose("[Encryption] \(tag) encrypted video_thumb uploaded, origin \(TransferLog.redact(origin)) attachmentId=\(info.attachmentId)")
                }
                if !applied {
                    logger.warn("[Encryption] \(tag) encrypted video_thumb uploaded after the 30 s timeout: not attached")
                }
            case .failure(let error):
                logger.warn("[Encryption] \(tag) video_thumb upload failed, sending without it: \(TransferLog.describe(error))")
                finish.fire()
            }
        }
        }
    }

    /// Writes a downloaded poster to the cache: decrypted with its `enc.renditions` entry
    /// when the video is encrypted, as is otherwise.
    static func storeVideoThumbnail(_ localUrl: URL, of attachment: ChatMessage.Attachment, at destination: URL) async throws {
        defer { TransferLog.remove(localUrl, what: "the downloaded poster", context: "[Attachment] video_thumb") }
        guard attachment.isEncrypted else {
            // Atomic write so a concurrent loadThumbnail never observes a
            // partially written JPEG (same pattern as SCTSession.thumbnailFile).
            try Data(contentsOf: localUrl).write(to: destination, options: .atomic)
            return
        }
        guard let encryption = attachment.encryption,
              let rendition = encryption.thumbnail
        else {
            logger.debug("[Encryption] video_thumb of \(attachment.transferLogDescription) cannot be decrypted: \(attachment.encryption == nil ? "enc unreadable" : "no thumbnail rendition in enc")")
            throw AttachmentEncryptionError.invalidEncryptionInfo
        }
        // Decrypted next to the cache and moved in whole: a reader never sees a prefix.
        let decrypted = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString)-\(destination.lastPathComponent)")
        do {
            try await Components.fileEncryption.decrypt(
                file: localUrl,
                to: decrypted,
                encryptionInfo: encryption.info(of: rendition),
                plaintextSize: nil
            )
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: decrypted)
            } else {
                try FileManager.default.moveItem(at: decrypted, to: destination)
            }
        } catch {
            // The caller reports it (and retries on the next bind).
            logger.debug("[Encryption] video_thumb of \(attachment.transferLogDescription) decrypt/store failed: \(TransferLog.describe(error))")
            TransferLog.remove(decrypted, what: "the partial poster", context: "[Encryption] video_thumb", level: .error)
            throw error
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
                        logger.warn("[Attachment] video_thumb download failed, origin \(TransferLog.redact(origin)): \(TransferLog.describe(error)) \(atch.transferLogDescription)")
                    }
                    return
                }
                let destination = URL(fileURLWithPath: FileStorage.default.videoThumbnailCachePath(origin: origin))
                Task {
                    do {
                        try await Self.storeVideoThumbnail(localUrl, of: atch, at: destination)
                    } catch {
                        logger.warn("[Attachment] video_thumb store failed, origin \(TransferLog.redact(origin)): \(TransferLog.describe(error)) \(atch.transferLogDescription)")
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
            if let blocks = self.cache[key], !blocks.isEmpty {
                blocks.forEach {
                    $0.progress?(attachmentProgress)
                }
            } else if self.unobservedProgressKeys.insert(key).inserted {
                // Normal when no cell for it is on screen. When one is, the emitter and the
                // subscriber disagree on the attachment's identity: the ring stays frozen at
                // its bind-time floor until the transfer completes.
                logger.verbose("[Attachment] \(taskInfo.logTag) progress has no observer for KEY \(TransferLog.redact(key)) (no cell on screen?)")
            }
            self.progressCache[key] = progress
        }
        
        func onCompletion(
            taskInfo: SCTDataSessionTaskInfo,
            attachment: ChatMessage.Attachment,
            error: Error? = nil
        ) {
            let key = Self.key(message: taskInfo.message, attachment: taskInfo.attachment)
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

        // Each task with its own attachment: `tasks` and `attachments` are not parallel (an
        // attachment already uploading has no task here).
        for taskInfo in tasks {
            let atch = taskInfo.attachment
            taskInfo.onEvent = { [weak self] event in
                guard let self else { return }
                // The hot path: no log context to build.
                if case .updateProgress(let progress) = event {
                    onProgress(progress, taskInfo: taskInfo)
                    return
                }
                // Every layer this event reaches (`enc` parsing, the poster) tags its lines
                // with this transfer.
                TransferLog.with(taskInfo.logContext) {
                    // Not a `switch`: progress has been handled above.
                    if case .updateLocalFileURL(let url, let filePath) = event {
                        self.updateLocalFile(url, previousPath: filePath, attachment: atch, taskInfo: taskInfo, message: message)
                    } else if case .successURL(let url) = event {
                        logger.verbose("[Attachment] \(taskInfo.logTag) success \(TransferLog.redact(url))")
                        finishSuccess(uri: url.absoluteString, taskInfo: taskInfo, atch: atch)
                    } else if case .successURI(let uri) = event {
                        logger.verbose("[Attachment] \(taskInfo.logTag) success \(TransferLog.redact(uri))")
                        finishSuccess(uri: uri, taskInfo: taskInfo, atch: atch)
                    } else if case .failure(let error) = event {
                        switch taskInfo.transferType {
                        case .download:
                            if atch.status != .pauseDownloading {
                                atch.status = .failedDownloading
                            }
                        case .upload:
                            if atch.status != .pauseUploading {
                                atch.status = Self.uploadStatus(
                                    afterFailure: error,
                                    userCancelled: taskInfo.action == .cancel,
                                    interrupted: taskInfo.wasInterrupted
                                )
                            }
                        }
                        // The one line for this failure, with its whole cause chain: the
                        // layers below logged it at debug.
                        Self.logSummary(taskInfo, attachment: atch, error: error)
                        onCompletion(taskInfo: taskInfo, attachment: atch, error: error)
                        AttachmentTransferStatusRelay.default.post(atch, status: atch.status)
                        didEndTask(taskInfo: taskInfo, error: error)
                    }
                }
            }
        }
        
        func finishSuccess(uri: String, taskInfo: SCTDataSessionTaskInfo, atch: ChatMessage.Attachment) {
            let tag = taskInfo.logTag
            if let error = Self.encryptionGateError(taskInfo: taskInfo, attachment: atch) {
                logger.debug("[Encryption] \(tag) rejecting success of \(taskInfo.transferType) (fail closed): \(TransferLog.describe(error)) uploadedEncryption=\(taskInfo.uploadedEncryption != nil) decrypted=\(taskInfo.didDecryptDownload)")
                switch taskInfo.transferType {
                case .upload:
                    // Not delivered: keep it an unsent attachment, and keep its url out of
                    // the checksum table so nothing dedupes onto the plaintext object.
                    atch.url = nil
                case .download:
                    // Whatever the session stored is ciphertext, not the file.
                    if let filePath = atch.filePath {
                        TransferLog.remove(URL(fileURLWithPath: filePath), what: "the undecrypted download", context: "[Encryption] \(tag) gate", level: .error)
                    }
                    atch.filePath = nil
                    atch.transferProgress = 0
                }
                taskInfo.reject(error: error)
                return
            }
            // For a just-uploaded video, upload its poster frame too before completing,
            // so the merged "video_thumb" metadata is persisted by didEndTask and rides
            // the wire message the sender builds from this attachment.
            attachVideoThumbnailIfNeeded(taskInfo: taskInfo, message: message, attachment: atch) {
                TransferLog.with(taskInfo.logContext) {
                    if taskInfo.transferType == .upload, let encryption = Self.uploadEncryption(of: taskInfo, attachment: atch) {
                        // The receiver's keys (the file's, and the poster's when one went out), and
                        // the original size for display: the stored object is larger.
                        // Ids and algorithm only: the keys are never logged.
                        logger.debug("[Encryption] \(tag) upload enc alg=\(encryption.algorithm) attachmentId=\(encryption.attachmentId) thumbnailAttachmentId=\(encryption.thumbnail?.attachmentId ?? "-")")
                        do {
                            atch.updateMetadata(try ChatMessage.Attachment.metadata(atch.metadata, settingEncryption: encryption))
                        } catch {
                            // Sent without its key, the file could never be opened.
                            logger.debug("[Encryption] \(tag) upload cannot write enc into the metadata: \(TransferLog.describe(error))")
                            atch.url = nil
                            taskInfo.reject(error: AttachmentEncryptionError.metadataFailed(error))
                            return
                        }
                        if let size = taskInfo.uploadedPlaintextSize {
                            atch.uploadedFileSize = UInt(size)
                        }
                    }
                    atch.url = uri
                    atch.transferProgress = 1
                    atch.status = .done
                    onCompletion(taskInfo: taskInfo, attachment: atch)
                    Self.logSummary(taskInfo, attachment: atch, error: nil, reference: uri)
                    // `.done` is relayed once, by `didEndTask`, after it is persisted.
                    didEndTask(taskInfo: taskInfo, error: nil)
                }
            }
        }

        func didEndTask(taskInfo: SCTDataSessionTaskInfo, error: Error?) {
            let key = Self.key(message: taskInfo.message, attachment: taskInfo.attachment)
            let groupKey = message.id != 0 ? Int64(message.id) : message.tid
            let tag = taskInfo.logTag
            // The task is over — no progress/completion event will ever fire for this
            // key again. Drop the cached percent so a later cell rebind that still
            // reads a stale `.downloading` status can't restore a progress ring that
            // nothing would ever hide.
            self.progressCache[key] = nil
            self.unobservedProgressKeys.remove(key)
            var storedMessage: ChatMessage?
            self.database.write(resultQueue: .global()) {
                storedMessage = $0.update(chatMessage: message, attachments: attachments)?.convert()
                for attachment in attachments where attachment.url != nil {
                    $0.updateChecksum(data: attachment.url!, messageTid: message.tid, attachmentTid: attachment.tid)
                }
            } completion: { dbError in
                if let dbError {
                    logger.error("[Attachment] \(tag) \(taskInfo.transferType) end could not be persisted: \(TransferLog.describe(dbError)) \(taskInfo.attachment.transferLogDescription)")
                }
                // The one relay of a successful transfer, and its last word: a pause that
                // slipped in just before the success relayed `.pauseUploading`.
                if error == nil, taskInfo.attachment.status == .done {
                    AttachmentTransferStatusRelay.default.post(taskInfo.attachment, status: .done)
                }
                completion?(storedMessage ?? message, error)
                // Taken in one locked step: a caller appending meanwhile is either in this
                // batch or kept for the next end of the key.
                var callbacks: [_CallBack]?
                switch taskInfo.transferType {
                case .upload:
                    self._uploadCallbackCache.mutate { callbacks = $0.removeValue(forKey: key) }
                case .download:
                    self._downloadCallbackCache.mutate { callbacks = $0.removeValue(forKey: key) }
                }
                for callback in callbacks ?? [] {
                    callback.callback?(storedMessage ?? message, error)
                }
            }
            // Only this task is over. Clearing the whole group left the message's other
            // attachments with no entry to guard against, so the next cell rebind started a
            // second download for bytes already in flight. One locked step: a start merging
            // its tasks into the group meanwhile is not overwritten.
            var survivors: Int?
            self._taskGroups.mutate { groups in
                guard let taskInfos = groups[groupKey] else { return }
                let remaining = taskInfos.filter { $0 !== taskInfo }
                groups[groupKey] = remaining.isEmpty ? nil : remaining
                survivors = remaining.count
            }
            if let survivors {
                logger.verbose("[Attachment] \(tag) task removed, \(survivors) other task(s) of the message still running")
            }
        }
    }

    /// The status of an upload that failed with `error`. Being offline is not a refusal: the
    /// upload fails the instant there is no network, and `.failedUploading` would swap the
    /// loader for a retry arrow on a message the app resends by itself on the next connect
    /// (`SyncService.resendPendingMessage`), so it is parked back in the queue. A refusal by
    /// encryption, or a file that is gone, fails.
    ///
    /// A cancel by the user (`SCTDataSessionTaskInfo.cancel`, or a cancellation the session did
    /// not report as an interruption) is `.pauseUploading`: the one upload status
    /// `SyncService.resendPendingMessage` skips, so a reconnect never sends what the user
    /// abandoned; a tap on it resends, as on `.failedUploading`. A cancellation reported as an
    /// interruption is parked like an offline failure: it is resent.
    static func uploadStatus(
        afterFailure error: Error?,
        userCancelled: Bool = false,
        interrupted: Bool = false
    ) -> ChatMessage.Attachment.TransferStatus {
        if userCancelled || (TransferLog.isCancellation(error) && !interrupted) {
            return .pauseUploading
        }
        if TransferLog.isCancellation(error) {
            return .pending
        }
        if error is AttachmentEncryptionError {
            return .failedUploading
        }
        if case .missingSourceFile? = error as? TransportDataSessionError {
            return .failedUploading
        }
        return isOffline ? .pending : .failedUploading
    }

    /// The one line a transfer ends with: info for a success, warn for an interruption, a
    /// pause or a cancel, error for a failure, which it reports with its whole cause chain.
    static func logSummary(_ taskInfo: SCTDataSessionTaskInfo, attachment atch: ChatMessage.Attachment, error: Error?, reference: String? = nil) {
        let duration = Int((Date().timeIntervalSince(taskInfo.startedAt) * 1000).rounded())
        var size = Int64(atch.uploadedFileSize)
        if size <= 0, let filePath = atch.filePath, error == nil {
            size = TransferLog.size(URL(fileURLWithPath: filePath)) ?? 0
        }
        let result: String
        let level: SceytChatUIKit.Logger.LogLevel
        if error == nil {
            result = "success"
            level = .info
        } else if TransferLog.isCancellation(error) {
            result = "cancelled"
            level = .warning
        } else if atch.status == .pauseUploading || atch.status == .pauseDownloading {
            result = "paused"
            level = .warning
        } else if taskInfo.wasInterrupted || atch.status == .pending {
            result = "interrupted"
            level = .warning
        } else {
            result = "failure"
            level = .error
        }
        var line = "[Attachment] \(taskInfo.logTag) transfer finished"
        line += " dir=\(taskInfo.transferType == .upload ? "upload" : "download")"
        line += " type=\(taskInfo.encryption == .required ? "encrypted" : "plain")"
        line += " size=\(size > 0 ? "\(size)" : "-")"
        line += " attempts=\(taskInfo.attempts)"
        line += " duration=\(duration)ms"
        line += " result=\(result)"
        line += " error=\(error.map { TransferLog.describe($0) } ?? "-")"
        line += " status=\(atch.status)"
        if let reference {
            line += " ref=\(TransferLog.redact(reference))"
        }
        line += " tid=\(atch.tid) id=\(atch.id) kind=\(atch.type)"
        switch level {
        case .error:
            logger.error(line)
        case .warning:
            logger.warn(line)
        default:
            logger.info(line)
        }
    }

    /// The file of `attachment` is now at `url` (prepared for its upload, or downloaded):
    /// the metadata follows the file, and the attachment is persisted.
    private func updateLocalFile(
        _ url: URL,
        previousPath filePath: String?,
        attachment atch: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo,
        message: ChatMessage
    ) {
        let previousMetadata = atch.metadata
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
        // The typed rebuild above only knows the media keys.
        atch.metadata = ChatMessage.Attachment.metadata(atch.metadata, preservingEncryptionFrom: previousMetadata)
        atch.name = url.lastPathComponent
        atch.filePath = url.path
        let fileSize = Components.storage.sizeOfItem(at: url)
        // An encrypted download is only the file once it was decrypted;
        // before that this is ciphertext, whose size is `cl`, not `ps`.
        let isPlaintext = taskInfo.transferType == .upload
            || taskInfo.encryption == .none
            || taskInfo.didDecryptDownload
        if fileSize > 0, isPlaintext {
            atch.uploadedFileSize = fileSize
        }
        if taskInfo.transferType == .download, fileSize > 0, isPlaintext {
            atch.transferProgress = 1
            atch.status = .done
        }
        taskInfo.attachment = atch
        logger.verbose("[Attachment] \(taskInfo.logTag) local file now \(url.lastPathComponent) (\(fileSize) B), persisted by \(filePath != nil ? "its previous path" : "the attachment")")
        self.database.write {
            if let filePath {
                $0.updateAttachment(with: filePath, chatMessage: message, attachment: atch)
            } else {
                $0.update(chatMessage: message, attachments: [atch])
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

// MARK: - Encryption

extension AttachmentTransfer {

    /// What `…Encryption` found for one attachment that must be encrypted.
    struct EncryptionSetup {
        /// The received attachment's `enc`; nil for an upload.
        var download: AttachmentEncryption?
        /// Why it cannot be transferred, e.g. a malformed encryption field.
        var error: Error?
    }

    /// The attachments the key provider says must be encrypted. Their keys are made by the
    /// transport's `FileEncryption` session, once UIKit hands it the prepared file
    /// (`FileUploadType.encrypted`).
    func uploadEncryption(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]
    ) -> [ObjectIdentifier: EncryptionSetup] {
        let provider = Components.attachmentKeyProvider
        var setups = [ObjectIdentifier: EncryptionSetup]()
        for attachment in attachments where attachment.filePath != nil
            && provider.requirement(for: attachment, in: message) == .required {
            setups[ObjectIdentifier(attachment)] = EncryptionSetup()
        }
        logger.debug("[Encryption] \(TransferLog.currentTag) upload of message tid=\(message.tid): \(setups.count) of \(attachments.count) attachment(s) must be encrypted (provider \(type(of: provider)))")
        return setups
    }

    /// The received attachments that carry `enc`. A malformed one, or one of a version or
    /// algorithm this build cannot read, fails before anything is fetched.
    func downloadEncryption(attachments: [ChatMessage.Attachment]) -> [ObjectIdentifier: EncryptionSetup] {
        var setups = [ObjectIdentifier: EncryptionSetup]()
        for attachment in attachments where attachment.isEncrypted {
            guard let encryption = attachment.encryption,
                  encryption.algorithm == StreamingAeadFileEncryptionProvider.format
            else {
                // The task fails with it and reports it.
                logger.debug("[Encryption] \(TransferLog.currentTag) download rejected: \(attachment.encryption == nil ? "malformed enc or unsupported version" : "unsupported algorithm \(attachment.encryption?.algorithm ?? "-")") \(attachment.transferLogDescription)")
                setups[ObjectIdentifier(attachment)] = EncryptionSetup(error: AttachmentEncryptionError.invalidEncryptionInfo)
                continue
            }
            // Ids and algorithm only: the keys are never logged.
            logger.debug("[Encryption] \(TransferLog.currentTag) download enc \(attachment.transferLogDescription) alg=\(encryption.algorithm) attachmentId=\(encryption.attachmentId) thumbnailAttachmentId=\(encryption.thumbnail?.attachmentId ?? "-")")
            setups[ObjectIdentifier(attachment)] = EncryptionSetup(download: encryption)
        }
        return setups
    }

    /// Marks `taskInfo` as an encrypted transfer. Returns the error to fail it with when it
    /// cannot run encrypted (fail-closed rule 1, malformed encryption field).
    static func apply(_ setup: EncryptionSetup, to taskInfo: SCTDataSessionTaskInfo, dataSession: SCTDataSession) -> Error? {
        taskInfo.encryption = .required
        taskInfo.downloadEncryption = setup.download
        guard dataSession.supportsAttachmentEncryption else {
            return AttachmentEncryptionError.encryptionUnsupportedBySession
        }
        return setup.error
    }

    /// Fail-closed rules 2 and 4: an encrypted upload succeeds only with the encryption its
    /// transport returned (or a dedupe hit that reused an encrypted object together with its
    /// key); an encrypted download only with the plaintext its transport verified.
    static func encryptionGateError(taskInfo: SCTDataSessionTaskInfo, attachment: ChatMessage.Attachment) -> Error? {
        guard taskInfo.encryption == .required else { return nil }
        switch taskInfo.transferType {
        case .upload:
            guard taskInfo.uploadedEncryption != nil || attachment.encryption != nil else {
                return AttachmentEncryptionError.encryptionBypassed
            }
        case .download:
            guard taskInfo.didDecryptDownload else {
                return AttachmentEncryptionError.encryptionBypassed
            }
        }
        return nil
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

    /// Returns whether this call ran the block.
    @discardableResult
    func fire() -> Bool {
        lock.lock()
        let block = self.block
        self.block = nil
        lock.unlock()
        block?()
        return block != nil
    }

    /// Runs `work`, then the block, only if the block hasn't fired yet: what `work` records
    /// is never applied after a timeout already went on without it.
    @discardableResult
    func fire(after work: () -> Void) -> Bool {
        lock.lock()
        let block = self.block
        self.block = nil
        if block != nil {
            work()
        }
        lock.unlock()
        block?()
        return block != nil
    }
}


private struct _Obj {
    var progress: AttachmentTransfer.ProgressBlock?
    var completion: AttachmentTransfer.CompletionBlock?
    var idKey: String
}

private struct _CallBack {
    var callback: ((ChatMessage?, Error?) -> Void)?
}

private typealias FileProviderCache = [String: [_Obj]]
private typealias ProgressCache = [String: Double]
private typealias CallbackCache = [String: [_CallBack]]

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
