//
//  AttachmentTransfer.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import UIKit.UIImage

let fileProvider = Components.attachmentTransfer.default

/// Safe to share between threads: every entry point runs on `tasksQueue`, the shared
/// collections (`taskGroups`, the observers, the posters' work) are behind their own locks,
/// and the configuration (`store`, `environment`, `connectivity`, `now`, `metricsObserver`)
/// is set before the first transfer and only read after.
open class AttachmentTransfer: DataProvider, @unchecked Sendable {
    
    public typealias ProgressBlock = (AttachmentProgress) -> Void
    public typealias CompletionBlock = (AttachmentCompletion) -> Void
    
    private let tasksQueue = DispatchQueue(label: "com.sceytchat.uikit.attachmentTransfer")
    nonisolated(unsafe) public static var `default` = Components.attachmentTransfer.init()
    
    /// Where transfers persist what they change.
    open var store: TransferStore = DatabaseTransferStore()

    /// The dependencies transfers use. Set it before the first transfer.
    public var environment = TransferEnvironment.components

    /// Told about every transfer that ends (not retained).
    public weak var metricsObserver: TransferMetricsObserver?

    /// Whether the device is offline now; the class's `isOffline` when not set. Set it before
    /// the first transfer (it is read from the transfer queues).
    public var connectivity: (() -> Bool)?

    /// The clock transfers are timed with. Set it before the first transfer.
    public var now: () -> Date = Date.init

    var isDeviceOffline: Bool {
        connectivity?() ?? type(of: self).isOffline
    }

    required public override init() {
        super.init()
        tasksQueue.setSpecific(key: Self.tasksQueueKey, value: ObjectIdentifier(self))
        posters.host = self
    }
    
    /// Who listens to which transfer, and the callers waiting for running ones.
    let observers = ProgressObserverRegistry()
    @Atomic private var taskGroups = [Int64: [SCTDataSessionTaskInfo]]()
    /// Video posters: made and sent with a video, fetched for a received one.
    let posters = VideoPosterTransfer()
    
    /// Progress reported for an upload the moment its task is created, before any
    /// byte-level callback exists. Small enough to read as "just started" (the UI shows
    /// `Upload.preparing` under 0.01) but > 0, which is what makes the ring visible at all
    /// — `onProgress` ignores non-positive values and the attachment views hide the ring
    /// at 0.
    nonisolated(unsafe) public static var initialUploadProgress: Double = 0.001

    /// Whether the client currently has no connection to the server. An upload failure
    /// raised in this state says nothing about the file or the server — only that there is
    /// nothing to send over — so it is treated as "wait", not as "failed".
    open class var isOffline: Bool {
        SceytChatUIKit.shared.chatClient.connectionState != .connected
    }

    /// How long a video's poster upload may take before the video goes out without it. A test
    /// seam: 30 s in production.
    var videoThumbnailTimeout: TimeInterval {
        get { posters.timeout }
        set { posters.timeout = newValue }
    }

    public var allTasks: [SCTDataSessionTaskInfo] {
        taskGroups.values.flatMap({ $0 })
    }
    
    open func dataSession(for message: ChatMessage? = nil, forAttachment: ChatMessage.Attachment? = nil) -> SCTDataSession? {
        environment.dataSession()
    }

    /// The server accepted `message` (`ChannelMessageSender`'s send and resend acks): the
    /// data session can let go of what it kept to report its uploads again.
    open func messageWasSent(_ message: ChatMessage) {
        guard message.attachments?.contains(where: { $0.tid != 0 && $0.type != "link" }) == true,
              let session = dataSession(for: message) as? TransportDataSession
        else { return }
        session.messageSent(message)
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
    
    static func key(message: ChatMessage, attachment: ChatMessage.Attachment) -> String {
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
        observers.register(
            key: Self.key(message: message, attachment: attachment),
            idKey: objectIdKey,
            progress: block,
            completion: completion
        )
    }
    
    open func currentProgressPercent(message: ChatMessage, attachment: ChatMessage.Attachment) -> Double? {
        observers.progress(forKey: Self.key(message: message, attachment: attachment))
    }
    
    open func removeProgressObserver(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        objectIdKey: String = ""
    ) {
        let key = Self.key(message: message, attachment: attachment)
        // Only the caller's registration: other screens may observe the same attachment.
        let dropped = observers.remove(key: key, idKey: objectIdKey)
        if objectIdKey.isEmpty, dropped > 1 {
            logger.warn("[Attachment] removeProgressObserver called with no objectIdKey — dropped all \(dropped) observers for \(TransferLog.redact(key)), including ones this caller does not own")
        }
        // The cached percent belongs to the transfer, not to any one observer: it is
        // what a later rebind reads to restore the ring. Keep it while a task is
        // still running; `didEndTask` clears it when the transfer really is over.
        let liveTask = taskFor(message: message, attachment: attachment) != nil
        if !liveTask {
            observers.forgetProgress(forKey: key)
        }
    }
    
    open func uploadMessageAttachments(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        onQueue {
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

    
    /// Reconciles what is on disk and starts the downloads that are still needed.
    ///
    /// Serialized on the transfer queue with every other entry point, so callers on main (a
    /// cell bind) and on global queues (reply views) never race each other's
    /// check-then-start. Synchronous, so the returned list is exact.
    /// - Returns: the attachments a download was started (or joined) for.
    @discardableResult
    open func downloadMessageAttachmentsIfNeeded(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) -> [ChatMessage.Attachment] {
        guard let attachments = attachments ?? message.attachments,
              !attachments.isEmpty
        else { return [] }
        return onTasksQueue {
            reconcileAndDownload(message: message, attachments: attachments, completion: completion)
        }
    }

    /// Returns once every call already handed to the transfer queue has run: its tasks are
    /// started and its statuses set (saves to the store may still be in flight).
    func waitForPendingWork() {
        onTasksQueue {}
    }

    /// Runs `work` on the transfer queue and waits for it; inline when already there.
    private func onTasksQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: Self.tasksQueueKey) == ObjectIdentifier(self) {
            return work()
        }
        return tasksQueue.sync(execute: work)
    }

    private static let tasksQueueKey = DispatchSpecificKey<ObjectIdentifier>()

    /// Runs `work` on the transfer queue, after every entry point called before it. What it
    /// captures (the caller's message, attachments and completion) is handed over: the queue
    /// runs every use of it here, one entry point at a time.
    private func onQueue(_ work: @escaping () -> Void) {
        let work = Handoff(work)
        tasksQueue.async { work.value() }
    }

    open func downloadMessageAttachments(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        onQueue {
            guard let attachments = attachments ?? message.attachments
            else {
                logger.verbose("[Attachment] downloadMessageAttachments: nothing to download, message \(message.id) has no attachments")
                completion?(message, nil)
                return
            }
            self.startDownloads(message: message, attachments: attachments, completion: completion)
        }
    }

    
    /// - Parameters:
    ///   - reason: who asked (a screen's button), for the log: a pause nobody remembers asking
    ///     for is otherwise indistinguishable from one the app made. `file`/`line` name the call.
    open func stopTransfer(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        reason: String = "unspecified",
        file: String = #fileID,
        line: UInt = #line,
        completion: ((Bool) -> Void)? = nil) {
        onQueue {
            let task = self.taskFor(message: message, attachment: attachment)
            logger.info("[Attachment] \(task?.logTag ?? "-") pause requested by \(reason) (\(file):\(line)) status=\(attachment.status) liveTask=\(task != nil) \(attachment.transferLogDescription)")
            guard let task
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
                self.store.save([attachment], of: message)
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
            self.setPaused(true, task: task, message: message, attachment: attachment, completion: completion)
        }
    }
    
    open func resumeTransfer(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        reason: String = "unspecified",
        file: String = #fileID,
        line: UInt = #line,
        completion: ((Bool) -> Void)? = nil) {
        onQueue {
            let task = self.taskFor(message: message, attachment: attachment)
            logger.info("[Attachment] \(task?.logTag ?? "-") resume requested by \(reason) (\(file):\(line)) status=\(attachment.status) liveTask=\(task != nil) \(attachment.transferLogDescription)")
            guard let task
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
            self.setPaused(false, task: task, message: message, attachment: attachment, completion: completion)
        }
    }

    /// Pauses (or resumes) `task`'s attachment on `message`: the status is saved first and
    /// the task told after, so it never acts on a state the store does not have.
    private func setPaused(
        _ paused: Bool,
        task: SCTDataSessionTaskInfo,
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: ((Bool) -> Void)?
    ) {
        // Matched by transfer identity, not `id`: every attachment of an incoming message has
        // `id == 0` until the server assigns one, so an `id` match would pick whichever
        // attachment comes first.
        let identity = Self.transferIdentity(of: attachment)
        guard let match = message.attachments?.first(where: { Self.transferIdentity(of: $0) == identity }) else {
            logger.error("[Attachment] \(paused ? "pause" : "resume"): no attachment on the message matches \(TransferLog.redact(identity)), status unchanged")
            completion?(false)
            return
        }
        match.status = Self.status(of: task.transferType, paused: paused)
        // Only this attachment: its siblings belong to their own transfers.
        store.save([match], of: message) { _ in
            if paused {
                task.stop()
            } else {
                task.resume()
            }
        }
        AttachmentTransferStatusRelay.default.post(match, status: match.status)
        completion?(true)
    }

    /// The status of a running (or paused) transfer of `type`.
    static func status(of type: SCTDataSessionTaskInfo.TransferType, paused: Bool) -> ChatMessage.Attachment.TransferStatus {
        switch (type, paused) {
        case (.download, true): return .pauseDownloading
        case (.download, false): return .downloading
        case (.upload, true): return .pauseUploading
        case (.upload, false): return .uploading
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
        let config = environment.imageResizeConfig()
        let failed = { (step: String) -> URL? in
            logger.warn("[Attachment] \(TransferLog.currentTag) video poster not made: \(step) \(attachment.transferLogDescription)")
            return nil
        }
        guard let path, FileManager.default.fileExists(atPath: path) else {
            return failed("no local file")
        }
        guard let frame = environment.videoProcessor().copyFrame(url: URL(fileURLWithPath: path)) else {
            return failed("no frame could be read from the video")
        }
        let builder: ImageBuilder
        do {
            builder = try environment.imageBuilder().init(image: frame).resize(max: config.dimensionThreshold)
        } catch {
            return failed("the frame could not be resized (\(TransferLog.describe(error)))")
        }
        guard let data = builder.jpegData(compressionQuality: config.compressionQuality) else {
            return failed("the frame could not be encoded as JPEG")
        }
        guard let file = environment.storage().storeInTemporaryDirectory(data: data, filename: "video_thumb_\(attachment.tid)", ext: "jpg") else {
            return failed("the poster could not be written")
        }
        return file
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
        posters.attach(taskInfo: taskInfo, message: message, attachment: atch, completion: completion)
    }

    /// Local cache path of a downloaded "video_thumb" poster, or nil if not cached.
    open func cachedVideoThumbnailPath(attachment: ChatMessage.Attachment) -> String? {
        posters.cachedPath(attachment: attachment)
    }

    /// Whether `downloadVideoThumbnailsIfNeeded` would actually fetch anything for this
    /// attachment. Answerable from the attachment alone, unlike the fetch itself, which
    /// needs the owner message — attachment list view models call this first so the
    /// overwhelmingly common no-op case costs no message lookup (a database round trip
    /// per bound cell in `ChannelAttachmentListViewModel`).
    open func needsVideoThumbnailDownload(attachment: ChatMessage.Attachment) -> Bool {
        posters.needsFetch(attachment: attachment)
    }

    /// Downloads the "video_thumb" poster for video attachments whose video file is
    /// not local yet, so the receiver can show a sharp preview while the (much
    /// larger) video is still downloading. Failures are dropped silently and
    /// retried on the next cell bind.
    open func downloadVideoThumbnailsIfNeeded(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil
    ) {
        posters.fetch(message: message, attachments: attachments)
    }


    /// Hands `tasks` to a `TransferRun` that takes their events and ends them. Installed
    /// before any session sees a task: an event it reports at once is never lost.
    func handle(
        tasks: [SCTDataSessionTaskInfo],
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        TransferRun(transfer: self, message: message, attachments: attachments, completion: completion)
            .observe(tasks)
    }

}

// MARK: - Task groups

extension AttachmentTransfer {
    /// The tasks of the message `groupKey` names, running or ended.
    func tasks(inGroup groupKey: Int64) -> [SCTDataSessionTaskInfo]? {
        taskGroups[groupKey]
    }

    /// Adds `tasks` to the message's group in one locked step: tasks an earlier call still runs
    /// for the message stay in it, so the `existTasks` guards and pause / resume / progress
    /// lookups find all of them.
    func merge(_ tasks: [SCTDataSessionTaskInfo], intoGroup groupKey: Int64) {
        guard !tasks.isEmpty else { return }
        _taskGroups.mutate { $0[groupKey, default: []].append(contentsOf: tasks) }
    }

    /// Removes the ended `taskInfo` from its message's group, in one locked step (a start
    /// merging its tasks meanwhile is not overwritten). Only this task is over: the
    /// message's other tasks stay, or the next rebind would start their downloads again.
    /// - Returns: how many tasks of the message still run, nil when it had no group.
    func removeTask(_ taskInfo: SCTDataSessionTaskInfo, fromGroup groupKey: Int64) -> Int? {
        var survivors: Int?
        _taskGroups.mutate { groups in
            guard let taskInfos = groups[groupKey] else { return }
            let remaining = taskInfos.filter { $0 !== taskInfo }
            groups[groupKey] = remaining.isEmpty ? nil : remaining
            survivors = remaining.count
        }
        return survivors
    }
}

extension AttachmentTransfer: VideoPosterHost {}
