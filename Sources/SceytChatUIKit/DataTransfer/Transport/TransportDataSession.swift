//
//  TransportDataSession.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

/// The prepared plaintext an upload sends.
public struct PreparedUploadFile {
    public let file: URL
    /// Made for this upload (a resized image, an exported video): it becomes the attachment's
    /// file only once the upload lands, so a failed or offline attempt never replaces the
    /// original. False: the attachment's own file.
    public let isStaged: Bool

    public init(file: URL, isStaged: Bool) {
        self.file = file
        self.isStaged = isStaged
    }
}

public enum TransportDataSessionError: Error {
    /// The attachment has no local file to upload.
    case missingSourceFile
}

/// The `SCTDataSession` that routes attachments to a `FileTransferTransport`: it checks for a
/// duplicate, prepares the file (resize, export, zip), schedules uploads one at a time, turns
/// pause / resume / cancel into transport calls and reports results to the task. The transport
/// only moves bytes, plain or encrypted (`FileUploadType`).
///
/// A prepared file is staged per operation and reused by the next attempt of the same upload,
/// so a retry or a relaunch sends the bytes a transport may already have stored in part.
open class TransportDataSession: NSObject, SCTDataSession {

    public let transport: FileTransferTransport

    private let lock = NSLock()
    private var uploads = [ObjectIdentifier: UploadJob]()
    private var waiting = [UploadJob]()
    /// The upload holding the queue's only slot.
    private var active: UploadJob?
    private var downloads = [ObjectIdentifier: DownloadJob]()

    /// Whether this process is an app extension, which resizes images with less memory. A
    /// test seam: `Bundle.main.isAppExtension` in production.
    static var isAppExtension: () -> Bool = { Bundle.main.isAppExtension }

    /// Test hooks, run as an upload attempt is about to take its slot and as a download
    /// attempt is about to start: what happens to the transfer meanwhile is what they test.
    var willBeginUpload: ((SCTDataSessionTaskInfo) -> Void)?
    var willStartDownload: ((SCTDataSessionTaskInfo) -> Void)?

    public init(transport: FileTransferTransport) {
        self.transport = transport
        super.init()
        let directory = stagingDirectory
        DispatchQueue.global(qos: .utility).async {
            Self.purgeStaleStaging(in: directory)
        }
    }

    open var supportsAttachmentEncryption: Bool { true }

    /// Whether an upload first asks the checksum table for an object already stored.
    open var checksumsBeforeUpload: Bool {
        SceytChatUIKit.shared.config.preventDuplicateAttachmentUpload
    }

    // MARK: Identity

    /// Names an upload across attempts and relaunches. Only an outgoing attachment has a
    /// `tid`; without one nothing an attempt saves can be found again.
    open func uploadOperationId(for attachment: ChatMessage.Attachment) -> String {
        attachment.tid != 0 ? "upload-\(attachment.tid)" : "upload-\(UUID().uuidString)"
    }

    /// Names a download: short and stable (`download-tid…`, `download-id…`, or
    /// `download-url<hash>`), never the url itself, which can be long and signed.
    open func downloadOperationId(for attachment: ChatMessage.Attachment) -> String {
        Self.shortDownloadOperationId(for: attachment)
    }

    static func shortDownloadOperationId(for attachment: ChatMessage.Attachment) -> String {
        if attachment.tid != 0 {
            return "download-tid\(attachment.tid)"
        }
        if attachment.id != 0 {
            return "download-id\(attachment.id)"
        }
        if let url = attachment.url, !url.isEmpty {
            return "download-url\(TransferLog.shortHash(url))"
        }
        return "download-\(UUID().uuidString.prefix(8).lowercased())"
    }

    // MARK: Storage

    /// Moves (or copies) `path` into storage and returns where it is now.
    open func storeFile(atPath path: String, transferId: String, fileName: String?) -> String {
        FileStorage.default.store(transferId: transferId, fileName: fileName, file: path)
    }

    open func removeFile(atPath path: String) {
        FileStorage.default.remove(path: path)
    }

    open func updateThumbnailPath(transferId: String, filePath: String) {
        FileStorage.default.updateThumbnailPath(transferId: transferId, filePath: filePath)
    }

    /// Where a download's plaintext goes, the place `getFilePath` finds it afterwards.
    open func downloadDestination(for attachment: ChatMessage.Attachment) -> URL? {
        guard let string = attachment.url, let url = URL(string: string) else {
            logger.debug("[Transfer] \(TransferLog.currentTag) no download destination: url missing or unparsable (\(TransferLog.redact(attachment.url))) \(attachment.transferLogDescription)")
            return nil
        }
        let transferId = url.deletingLastPathComponent().lastPathComponent
        return URL(fileURLWithPath: FileStorage.default.createPath(transferId: transferId, fileName: attachment.name))
    }

    /// Prepared files waiting for their upload to land, one folder per operation.
    open var stagingDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("upload-staging", isDirectory: true)
    }

    // MARK: SCTDataSession

    open func getFilePath(attachment: ChatMessage.Attachment) -> String? {
        guard let filePath = attachment.filePath, FileManager.default.fileExists(atPath: filePath) else { return nil }
        return filePath
    }

    open func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? {
        nil
    }

    open func uploadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        fileUrl: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        DefaultThumbnailTransfer.upload(fileUrl: fileUrl, completion: completion)
    }

    open func downloadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        origin: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DefaultThumbnailTransfer.download(origin: origin, completion: completion)
    }

    open func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        if !taskInfo.hasAssignedOperationId {
            taskInfo.assign(operationId: uploadOperationId(for: attachment))
        }
        let job = UploadJob(
            attachment: attachment,
            taskInfo: taskInfo,
            operationId: taskInfo.operationId
        )
        let tag = taskInfo.logTag
        lock.lock()
        // A second start of an upload still running joins it: two jobs of one operation would
        // share its staging folder and the transport's record, and a cancel of one would end
        // the other's transfer.
        if let running = uploads.values.first(where: { $0.operationId == job.operationId && !$0.isFinished }) {
            running.joined.append(taskInfo)
            let state = running.state
            let attempt = running.attempt
            lock.unlock()
            taskInfo.attempts = attempt
            logger.info("[Transfer] \(tag) upload started again while attempt \(attempt) is \(state): joins it, no second transfer \(attachment.transferLogDescription)")
            taskInfo.onAction = actions(of: running)
            if case .paused = state {
                resume(running)
            }
            return
        }
        uploads[ObjectIdentifier(taskInfo)] = job
        lock.unlock()
        if attachment.tid == 0 {
            logger.warn("[Transfer] \(tag) upload has no tid: a retry or relaunch cannot find what this attempt saves \(attachment.transferLogDescription)")
        }
        logger.debug("[Transfer] \(tag) upload queued encryption=\(taskInfo.encryption) source=\(TransferLog.size(path: attachment.filePath)) \(attachment.transferLogDescription)")
        taskInfo.onAction = actions(of: job)
        enqueue(job)
    }

    private func actions(of job: UploadJob) -> (SCTDataSessionTaskInfo.Action) -> Void {
        { [weak self, weak job] action in
            guard let self, let job else { return }
            switch action {
            case .stop:
                self.pause(job)
            case .resume:
                self.resume(job)
            case .cancel:
                self.cancel(job)
            }
        }
    }

    private func actions(of job: DownloadJob) -> (SCTDataSessionTaskInfo.Action) -> Void {
        { [weak self, weak job] action in
            guard let self, let job else { return }
            switch action {
            case .stop:
                self.pause(job)
            case .resume:
                self.resume(job)
            case .cancel:
                self.cancel(job)
            }
        }
    }

    open func download(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        if !taskInfo.hasAssignedOperationId {
            taskInfo.assign(operationId: downloadOperationId(for: attachment))
        }
        let tag = taskInfo.logTag
        guard let url = attachment.url, !url.isEmpty,
              let destination = TransferLog.with(taskInfo.logContext, { downloadDestination(for: attachment) })
        else {
            // Reported at the end, once, by `AttachmentTransfer`.
            logger.debug("[Transfer] \(tag) download: unusable url or no destination, failing without a request url=\(TransferLog.redact(attachment.url)) \(attachment.transferLogDescription)")
            Task { self.report(taskInfo, .failure(FileTransferError.invalidRequest)) }
            return
        }
        let encryptionInfo = taskInfo.encryption == .required ? taskInfo.downloadEncryption?.fileInfo : nil
        let request = FileDownloadRequest(
            operationId: taskInfo.operationId,
            url: url,
            destinationFile: destination,
            encryptionInfo: encryptionInfo,
            // The size the sender sent: decryption verifies the object holds exactly that.
            plaintextSize: encryptionInfo != nil && attachment.uploadedFileSize > 0 ? Int64(attachment.uploadedFileSize) : nil,
            context: AttachmentTransferContext(message: taskInfo.message, attachment: attachment)
        )
        let job = DownloadJob(request: request, taskInfo: taskInfo)
        if taskInfo.encryption == .required, request.encryptionInfo == nil {
            // Fails closed later: the transport stores ciphertext and the gate rejects it.
            logger.warn("[Encryption] \(tag) download must be decrypted but has no enc; the request goes out without it \(attachment.transferLogDescription)")
        }
        lock.lock()
        // A second start of a download still running joins it: two invocations of one
        // operation would write the same destination, and only one could be controlled.
        if let running = downloads.values.first(where: { $0.request.operationId == request.operationId && !$0.isFinished }) {
            running.joined.append(taskInfo)
            let state = running.state
            let attempt = running.attempt
            lock.unlock()
            taskInfo.attempts = attempt
            logger.info("[Transfer] \(tag) download started again while attempt \(attempt) is \(state): joins it, no second transfer \(attachment.transferLogDescription)")
            taskInfo.onAction = actions(of: running)
            if case .paused = state {
                resume(running)
            }
            return
        }
        downloads[ObjectIdentifier(taskInfo)] = job
        lock.unlock()
        logger.debug("[Transfer] \(tag) download queued encrypted=\(request.encryptionInfo != nil) trustedSize=\(request.plaintextSize.map { "\($0) B" } ?? "-") url=\(TransferLog.redact(url)) destinationExists=\(FileManager.default.fileExists(atPath: destination.path)) \(attachment.transferLogDescription)")
        taskInfo.onAction = actions(of: job)
        start(job)
    }

    /// Abandons the uploads of `attachments`, running or only saved by the transport (after a
    /// relaunch nothing runs, but a remote multipart upload may still be open).
    open func cancel(attachments: [ChatMessage.Attachment]) {
        for attachment in attachments where attachment.tid != 0 {
            lock.lock()
            let job = uploads.values.first { $0.attachment.tid == attachment.tid }
            lock.unlock()
            if let job {
                logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) abandoned by cancel(attachments:) \(attachment.transferLogDescription)")
                cancel(job)
            } else {
                let operationId = uploadOperationId(for: attachment)
                logger.info("[Transfer] xfer=\(operationId) upload has no live job: abandoning what the transport saved \(attachment.transferLogDescription)")
                transport.cancel(operationId: operationId)
                discardStaged(operationId: operationId)
            }
        }
    }

    /// Stops every transfer without abandoning any (the network went away): each task fails
    /// with `error`, and the transport keeps what a later attempt can continue.
    open func interruptTransfers(error: Error) {
        lock.lock()
        let uploadJobs = Array(uploads.values)
        let downloadJobs = Array(downloads.values)
        for job in uploadJobs {
            job.state = .finished
        }
        for job in downloadJobs {
            job.state = .finished
        }
        uploads = [:]
        downloads = [:]
        waiting = []
        active = nil
        lock.unlock()
        logger.warn("[Transfer] interrupting \(uploadJobs.count) upload(s) and \(downloadJobs.count) download(s): \(TransferLog.describe(error))")
        for job in uploadJobs {
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) -> finished (interrupted)")
            job.stopWork()
            report(tasks(of: job), .failure(error), interrupted: true)
        }
        for job in downloadJobs {
            logger.debug("[Transfer] \(job.taskInfo.logTag) download attempt=\(attempt(of: job)) -> finished (interrupted)")
            job.task?.cancel()
            report(tasks(of: job), .failure(error), interrupted: true)
        }
    }

    // MARK: Upload queue

    private func enqueue(_ job: UploadJob) {
        lock.lock()
        guard active == nil else {
            waiting.append(job)
            let depth = waiting.count
            let holder = active?.operationId ?? "-"
            lock.unlock()
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload waiting for the upload slot (position \(depth), held by \(holder))")
            return
        }
        active = job
        lock.unlock()
        begin(job)
    }

    /// Gives up the slot `job` holds and starts the next upload.
    private func releaseSlot(of job: UploadJob) {
        lock.lock()
        guard active === job else {
            lock.unlock()
            return
        }
        active = nil
        let next = waiting.isEmpty ? nil : waiting.removeFirst()
        active = next
        lock.unlock()
        logger.debug("[Transfer] \(job.taskInfo.logTag) upload released the upload slot, next=\(next?.operationId ?? "-")")
        if let next {
            begin(next)
        }
    }

    /// `job` holds the slot: continue its paused invocation, or start a new attempt.
    private func begin(_ job: UploadJob) {
        willBeginUpload?(job.taskInfo)
        lock.lock()
        guard case .waiting(let alive) = job.state else {
            let state = job.state
            lock.unlock()
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) got the slot while \(state), not starting")
            releaseSlot(of: job)
            return
        }
        if alive {
            job.state = .uploading
            lock.unlock()
            if transport.resume(operationId: job.operationId) {
                logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) waiting -> uploading (resumed the live invocation)")
                return
            }
            logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) transport could not resume the paused invocation, starting a new attempt")
            lock.lock()
            guard case .uploading = job.state else {
                let state = job.state
                lock.unlock()
                logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) became \(state) during the failed resume, no new attempt")
                return
            }
        }
        job.attempt += 1
        let attempt = job.attempt
        job.state = .preparing
        let previous = job.task
        let tasks = [job.taskInfo] + job.joined
        lock.unlock()
        tasks.forEach { $0.attempts = attempt }
        logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt) waiting -> preparing \(job.attachment.transferLogDescription)")
        previous?.cancel()
        let context = job.taskInfo.logContext
        job.task = Task { [weak self] in
            // Every layer below (transport, encryption) tags its lines with this transfer.
            await TransferLog.$current.withValue(context) {
                await self?.run(job, attempt: attempt)
            }
        }
    }

    private func isCurrent(_ job: UploadJob, attempt: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard job.attempt == attempt else { return false }
        switch job.state {
        case .preparing, .uploading:
            return true
        default:
            return false
        }
    }

    private func run(_ job: UploadJob, attempt: Int) async {
        let taskInfo = job.taskInfo
        let tag = taskInfo.logTag
        if checksumsBeforeUpload {
            let stored = await withCheckedContinuation { continuation in
                taskInfo.startChecksum { continuation.resume(returning: $0) }
            }
            // A stored copy was reported by the checksum itself, and so was its failure.
            if stored || isTerminal(taskInfo) {
                logger.debug("[Transfer] \(tag) upload attempt=\(attempt) -> finished (\(stored ? "checksum hit, nothing uploaded" : "checksum step failed the task"))")
                finish(job, attempt: attempt)
                // A task that joined this one ends the same way.
                if let event = taskInfo.event {
                    report(joined(of: job), event)
                }
                return
            }
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) checksum miss, uploading")
        }
        guard isCurrent(job, attempt: attempt) else {
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) dropped after the checksum: stale or no longer preparing")
            return
        }

        let prepared: PreparedUploadFile
        do {
            prepared = try await prepareUploadFile(job)
        } catch {
            guard isCurrent(job, attempt: attempt) else {
                logger.debug("[Transfer] \(tag) upload attempt=\(attempt) preparation ended (\(TransferLog.describe(error))) after a pause/cancel/new attempt, dropped")
                return
            }
            // Reported at the end, once, by `AttachmentTransfer`.
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) preparing -> finished (failure): preparation failed \(TransferLog.describe(error))")
            finish(job, attempt: attempt)
            report(tasks(of: job), .failure(error))
            return
        }
        let preparedSize = TransferLog.size(prepared.file)
        if !FileManager.default.fileExists(atPath: prepared.file.path) {
            // Not handled: the transport is asked to send a file that is gone.
            logger.warn("[Transfer] \(tag) upload attempt=\(attempt) prepared file \(prepared.file.lastPathComponent) does not exist (source deleted?) \(job.attachment.transferLogDescription)")
        } else if preparedSize == 0 {
            // Sent as is. The checksum step never dedupes an empty file.
            logger.warn("[Transfer] \(tag) upload attempt=\(attempt) prepared file is 0 bytes \(job.attachment.transferLogDescription)")
        }
        guard startUploading(job, attempt: attempt) else {
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) paused, cancelled or superseded during preparation, not uploading")
            return
        }

        let type: FileUploadType = taskInfo.encryption == .required ? .encrypted : .plain
        let fileName = job.attachment.name?.isEmpty == false ? job.attachment.name! : prepared.file.lastPathComponent
        let request = FileUploadRequest(
            operationId: job.operationId,
            sourceFile: prepared.file,
            fileName: fileName,
            mimeType: Self.mimeType(of: prepared, fileName: fileName),
            context: AttachmentTransferContext(message: taskInfo.message, attachment: job.attachment),
            type: type
        )
        logger.info("[Transfer] \(tag) upload attempt=\(attempt) preparing -> uploading type=\(type) staged=\(prepared.isStaged) size=\(preparedSize.map { "\($0) B" } ?? "unknown") mime=\(request.mimeType ?? "-") \(job.attachment.transferLogDescription)")
        let result = await transport.upload(request) { [weak self, weak job] progress in
            guard let self, let job, self.isUploading(job, attempt: attempt) else { return }
            if let quarter = job.progressMilestone(progress) {
                logger.debug("[Transfer] \(tag) upload attempt=\(attempt) progress \(quarter)%")
            }
            self.tasks(of: job).forEach { $0.updateProgress(progress) }
        }
        handle(result, of: job, attempt: attempt, prepared: prepared, type: type)
    }

    /// A prepared file's type follows its own extension (a resized image is a JPEG whatever
    /// its source was); a file sent in place is typed by the name it is sent under, its own
    /// extension when that name has none.
    static func mimeType(of prepared: PreparedUploadFile, fileName: String) -> String? {
        let named = (fileName as NSString).pathExtension
        let ext = prepared.isStaged || named.isEmpty ? prepared.file.pathExtension : named
        return UTType(filenameExtension: ext)?.preferredMIMEType
    }

    /// Preparation is over and nothing paused or cancelled the attempt meanwhile.
    private func startUploading(_ job: UploadJob, attempt: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard job.attempt == attempt, case .preparing = job.state else { return false }
        job.state = .uploading
        return true
    }

    private func isUploading(_ job: UploadJob, attempt: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard job.attempt == attempt, case .uploading = job.state else { return false }
        return true
    }

    private func handle(
        _ result: FileTransferResult<FileUploadResult>,
        of job: UploadJob,
        attempt: Int,
        prepared: PreparedUploadFile,
        type: FileUploadType
    ) {
        let outcome = Self.describe(result)
        let tag = job.taskInfo.logTag
        lock.lock()
        guard job.attempt == attempt else {
            let current = job.attempt
            lock.unlock()
            logger.debug("[Transfer] \(tag) upload stale attempt=\(attempt) ended (\(outcome)) while attempt \(current) is current, dropped")
            return
        }
        switch (result, job.state) {
        case (_, .finished):
            lock.unlock()
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) ended (\(outcome)) after it was finished (cancelled/interrupted), dropped")
            return
        case (.success, _):
            // Landed, even while paused: the file is stored.
            break
        case (_, .paused):
            // The paused invocation ended without the file: a resume starts a new attempt.
            job.state = .paused(alive: false)
            lock.unlock()
            logger.info("[Transfer] \(tag) upload attempt=\(attempt) paused -> paused(alive: false): the paused invocation ended (\(outcome))")
            return
        case (_, .waiting):
            job.state = .waiting(alive: false)
            lock.unlock()
            logger.info("[Transfer] \(tag) upload attempt=\(attempt) waiting -> waiting(alive: false): the paused invocation ended (\(outcome))")
            return
        default:
            break
        }
        lock.unlock()
        finish(job, attempt: attempt)

        // Failures are reported at the end, once, by `AttachmentTransfer`: debug here.
        let tasks = tasks(of: job)
        switch result {
        case .success(let uploaded):
            if type == .encrypted, uploaded.encryptionInfo == nil {
                // Encrypted bytes without their key could never be opened.
                logger.debug("[Encryption] \(tag) upload attempt=\(attempt) -> finished (failure): transport reported success without encryptionInfo, rejected (encryptionBypassed)")
                report(tasks, .failure(AttachmentEncryptionError.encryptionBypassed))
                return
            }
            if type == .plain, uploaded.encryptionInfo != nil {
                logger.warn("[Encryption] \(tag) upload attempt=\(attempt) plain upload came back with encryptionInfo; it is kept \(job.attachment.transferLogDescription)")
            }
            // Checked before anything replaces the task's event: an event after the terminal
            // one would hide that the task ended, and the success would be reported over it.
            let live = tasks.filter { !$0.isTerminal }
            guard !live.isEmpty else {
                logger.debug("[Transfer] \(tag) upload attempt=\(attempt) landed after the task already ended (\(Self.describe(job.taskInfo.event))): result dropped")
                discardStaged(operationId: job.operationId)
                return
            }
            if prepared.isStaged {
                adopt(prepared.file, job: job, tasks: live)
            }
            discardStaged(operationId: job.operationId)
            var plaintextSize: Int64?
            if type == .encrypted {
                plaintextSize = Self.fileSize(prepared.file) ?? Self.fileSize(job.attachment.filePath.map { URL(fileURLWithPath: $0) })
                if plaintextSize == nil {
                    logger.warn("[Transfer] \(tag) upload attempt=\(attempt) plaintext size unknown after the upload: the message carries the stored size")
                }
            }
            for taskInfo in live {
                taskInfo.uploadedEncryption = uploaded.encryptionInfo
                if type == .encrypted {
                    taskInfo.uploadedPlaintextSize = plaintextSize
                }
            }
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) uploading -> finished (success) ref=\(TransferLog.redact(uploaded.remoteReference)) encrypted=\(uploaded.encryptionInfo != nil)")
            report(live, .successURI(uploaded.remoteReference))
        case .failure(let error):
            // The staged file stays: the next attempt sends it again.
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) uploading -> finished (failure): \(TransferLog.describe(error))")
            report(tasks, .failure(error))
        case .interrupted(let error):
            logger.debug("[Transfer] \(tag) upload attempt=\(attempt) uploading -> finished (interrupted, work kept for a retry): \(TransferLog.describe(error))")
            report(tasks, .failure(error), interrupted: true)
        }
    }

    /// The attempt is over: the job leaves the queue and the session.
    private func finish(_ job: UploadJob, attempt: Int) {
        lock.lock()
        guard job.attempt == attempt else {
            let current = job.attempt
            lock.unlock()
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload finish of stale attempt=\(attempt) ignored (current \(current))")
            return
        }
        let previous = job.state
        job.state = .finished
        uploads[ObjectIdentifier(job.taskInfo)] = nil
        lock.unlock()
        logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt) \(previous) -> finished")
        releaseSlot(of: job)
    }

    private func pause(_ job: UploadJob) {
        lock.lock()
        switch job.state {
        case .waiting(let alive):
            waiting.removeAll { $0 === job }
            job.state = .paused(alive: alive)
            lock.unlock()
            logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) waiting -> paused(alive: \(alive))")
        case .preparing:
            job.state = .paused(alive: false)
            lock.unlock()
            logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) preparing -> paused(alive: false), preparation stopped")
            job.stopWork()
            releaseSlot(of: job)
        case .uploading:
            lock.unlock()
            let alive = transport.pause(operationId: job.operationId)
            lock.lock()
            guard case .uploading = job.state else {
                let state = job.state
                lock.unlock()
                logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) pause raced to \(state), ignored")
                return
            }
            job.state = .paused(alive: alive)
            lock.unlock()
            logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) uploading -> paused(alive: \(alive))\(alive ? "" : ", invocation stopped")")
            if !alive {
                job.stopWork()
            }
            releaseSlot(of: job)
        case .paused, .finished:
            let state = job.state
            lock.unlock()
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) pause ignored while \(state)")
        }
    }

    private func resume(_ job: UploadJob) {
        lock.lock()
        guard case .paused(let alive) = job.state else {
            let state = job.state
            lock.unlock()
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) resume ignored while \(state)")
            return
        }
        job.state = .waiting(alive: alive)
        lock.unlock()
        logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) paused -> waiting(alive: \(alive)) (resumed)")
        enqueue(job)
    }

    private func cancel(_ job: UploadJob) {
        lock.lock()
        if case .finished = job.state {
            lock.unlock()
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) cancel ignored: already finished")
            return
        }
        let previous = job.state
        job.state = .finished
        waiting.removeAll { $0 === job }
        uploads[ObjectIdentifier(job.taskInfo)] = nil
        lock.unlock()
        logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) \(previous) -> finished (cancelled)")
        transport.cancel(operationId: job.operationId)
        job.stopWork()
        discardStaged(operationId: job.operationId)
        releaseSlot(of: job)
        // A terminal event, like a cancelled download's: the task leaves `AttachmentTransfer`,
        // so a later upload of the same file is a new one.
        report(tasks(of: job), .failure(URLError(.cancelled)))
    }

    // MARK: Preparation

    /// The file to upload for `attachment`: the file staged by an earlier attempt of the same
    /// operation, or a new one. Images are resized, videos exported, folders zipped; any other
    /// file is sent as it is, where it is.
    open func prepareUploadFile(
        for attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo,
        operationId: String,
        videoProcessInfo: SCVideoProcessInfo
    ) async throws -> PreparedUploadFile {
        guard var filePath = attachment.filePath else {
            logger.debug("[Transfer] \(taskInfo.logTag) upload has no local file to prepare (missingSourceFile)")
            throw TransportDataSessionError.missingSourceFile
        }
        if !FileManager.default.fileExists(atPath: filePath) {
            // Not handled here: preparation goes on and fails (or sends nothing) later.
            logger.warn("[Transfer] \(taskInfo.logTag) upload source file \((filePath as NSString).lastPathComponent) is missing \(attachment.transferLogDescription)")
        }
        if attachment.type == "image" || attachment.type == "video",
           let staged = stagedFile(operationId: operationId) {
            // An export or resize would make different bytes than the ones already sent.
            logger.info("[Transfer] \(taskInfo.logTag) upload staging reused: sends the file an earlier attempt prepared (\(TransferLog.sizeText(staged)))")
            return PreparedUploadFile(file: staged, isStaged: true)
        }
        taskInfo.updateProgress(0.01)
        switch attachment.type {
        case "video":
            switch await Components.videoProcessor.export(from: filePath, processInfo: videoProcessInfo) {
            case .success(let exported):
                try Task.checkCancellation()
                return PreparedUploadFile(file: try stage(exported, operationId: operationId, fileName: exported.lastPathComponent, tag: taskInfo.logTag), isStaged: true)
            case .failure(let error):
                logger.warn("[Transfer] \(taskInfo.logTag) upload video export failed (\(TransferLog.describe(error))), uploading the original")
            }
        case "image":
            let config = SceytChatUIKit.shared.config.imageAttachmentResizeConfig
            var jpeg: Data?
            if Self.isAppExtension() {
                jpeg = Components.imageBuilder.lowMemory_resizeImage(fileUrl: URL(fileURLWithPath: filePath), maxPixelSize: config.dimensionThreshold)?
                    .jpegData(compressionQuality: config.compressionQuality)
            } else if let builder = Components.imageBuilder.init(imageUrl: URL(fileURLWithPath: filePath)),
                      !builder.imageSize.isNan {
                jpeg = try? builder.resize(max: config.dimensionThreshold).jpegData(compressionQuality: config.compressionQuality)
            }
            try Task.checkCancellation()
            if let jpeg,
               let resized = Components.storage.storeInTemporaryDirectory(data: jpeg, filename: attachment.name ?? UUID().uuidString) {
                return PreparedUploadFile(file: try stage(resized, operationId: operationId, fileName: resized.lastPathComponent, tag: taskInfo.logTag), isStaged: true)
            }
            logger.warn("[Transfer] \(taskInfo.logTag) upload image resize \(jpeg == nil ? "failed" : "could not be stored"), uploading the original")
        case "file":
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                let zip = try await Components.storage.makeUploadingUrl(directoryUrl: URL(fileURLWithPath: filePath))
                try Task.checkCancellation()
                logger.debug("[Transfer] \(taskInfo.logTag) upload folder zipped (\(TransferLog.sizeText(zip)))")
                taskInfo.updateLocalFileLocation(newLocation: zip)
                filePath = zip.path
            } else {
                // Sent in place, as `SCTSession` always did: moving it into storage took the
                // attachment's own file away from where it was, and each retry moved it again
                // into a new folder, leaving the previous one empty.
                logger.debug("[Transfer] \(taskInfo.logTag) upload file sent in place (\(TransferLog.size(path: filePath)))")
            }
        default:
            break
        }
        return PreparedUploadFile(file: URL(fileURLWithPath: filePath), isStaged: false)
    }

    private func prepareUploadFile(_ job: UploadJob) async throws -> PreparedUploadFile {
        try await prepareUploadFile(
            for: job.attachment,
            taskInfo: job.taskInfo,
            operationId: job.operationId,
            videoProcessInfo: job.videoProcessInfo
        )
    }

    /// The upload landed: the staged file becomes the attachment's, and an image's original
    /// goes (the resized copy is what was sent).
    private func adopt(_ staged: URL, job: UploadJob, tasks: [SCTDataSessionTaskInfo]) {
        let tag = job.taskInfo.logTag
        guard FileManager.default.fileExists(atPath: staged.path) else {
            logger.warn("[Transfer] \(tag) upload landed but its staged file is gone: the attachment keeps its original file")
            return
        }
        let original = job.attachment.filePath
        let transferId = UUID().uuidString
        let path = storeFile(atPath: staged.path, transferId: transferId, fileName: staged.lastPathComponent)
        logger.debug("[Transfer] \(tag) upload staged file adopted as the attachment's file\(FileManager.default.fileExists(atPath: path) ? "" : " (missing after the move)")")
        tasks.forEach { $0.updateLocalFileLocation(newPath: path) }
        updateThumbnailPath(transferId: transferId, filePath: path)
        if job.attachment.type == "image", let original, original != path, original != staged.path {
            removeFile(atPath: original)
        }
    }

    private func stagingFolder(operationId: String) -> URL {
        let name = operationId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? operationId
        return stagingDirectory.appendingPathComponent(name, isDirectory: true)
    }

    private func stagedFile(operationId: String) -> URL? {
        let folder = stagingFolder(operationId: operationId)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles)) ?? []
        return files.first { (Self.fileSize($0) ?? 0) > 0 }
    }

    private func stage(_ file: URL, operationId: String, fileName: String, tag: String) throws -> URL {
        let fileManager = FileManager.default
        let folder = stagingFolder(operationId: operationId)
        TransferLog.remove(folder, what: "the old staging folder", context: "[Transfer] \(tag) upload")
        let staged = folder.appendingPathComponent(fileName.isEmpty ? "file" : fileName)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            try fileManager.moveItem(at: file, to: staged)
        } catch {
            logger.debug("[Transfer] \(tag) upload staging failed: \(TransferLog.describe(error))")
            throw error
        }
        logger.debug("[Transfer] \(tag) upload staging created (\(TransferLog.sizeText(staged)))")
        return staged
    }

    private func discardStaged(operationId: String) {
        let folder = stagingFolder(operationId: operationId)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        if TransferLog.remove(folder, what: "the staging folder", context: "[Transfer] xfer=\(operationId) upload") {
            logger.debug("[Transfer] xfer=\(operationId) upload staging cleaned up")
        }
    }

    /// How long a staged file nobody uploaded or abandoned is kept.
    static let staleStagingAge: TimeInterval = 7 * 24 * 60 * 60

    private static func purgeStaleStaging(in directory: URL) {
        let fileManager = FileManager.default
        let cutoff = Date().addingTimeInterval(-staleStagingAge)
        let folders = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        var purged = 0
        for folder in folders {
            let modified = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff,
               TransferLog.remove(folder, what: "a stale staging folder", context: "[Transfer] staging purge") {
                purged += 1
            }
        }
        if purged > 0 {
            logger.info("[Transfer] staging purge removed \(purged) of \(folders.count) folder(s) older than \(Int(staleStagingAge / 86_400)) days")
        }
    }

    static func fileSize(_ url: URL?) -> Int64? {
        guard let url, let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else { return nil }
        return Int64(size)
    }

    // MARK: Downloads

    private func start(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        willStartDownload?(job.taskInfo)
        lock.lock()
        if case .finished = job.state {
            lock.unlock()
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) not started: already finished")
            return
        }
        job.attempt += 1
        let attempt = job.attempt
        let previousState = job.state
        job.state = .running
        let previous = job.task
        let tasks = [job.taskInfo] + job.joined
        lock.unlock()
        tasks.forEach { $0.attempts = attempt }
        logger.info("[Transfer] \(tag) download attempt=\(attempt) \(attempt == 1 ? "queued" : "\(previousState)") -> running encrypted=\(job.request.encryptionInfo != nil) url=\(TransferLog.redact(job.request.url))")
        previous?.cancel()
        let encrypted = job.request.encryptionInfo != nil
        let context = job.taskInfo.logContext
        job.task = Task { [weak self] in
            guard let self else { return }
            // Every layer below (transport, encryption) tags its lines with this transfer.
            let result = await TransferLog.$current.withValue(context) {
                await self.transport.download(job.request) { [weak self, weak job] progress in
                    guard let self, let job, self.isRunning(job, attempt: attempt) else { return }
                    if let quarter = job.progressMilestone(progress) {
                        logger.debug("[Transfer] \(tag) download attempt=\(attempt) progress \(quarter)%")
                    }
                    // Not done when the last byte arrives: it still has to be verified and
                    // decrypted, so the bar stops short of full until then.
                    self.tasks(of: job).forEach { $0.updateProgress(encrypted ? min(progress, 0.99) : progress) }
                }
            }
            self.handle(result, of: job, attempt: attempt)
        }
    }

    private func isRunning(_ job: DownloadJob, attempt: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard job.attempt == attempt, case .running = job.state else { return false }
        return true
    }

    private func handle(_ result: FileTransferResult<URL>, of job: DownloadJob, attempt: Int) {
        let tag = job.taskInfo.logTag
        let outcome = Self.describe(result)
        lock.lock()
        guard job.attempt == attempt else {
            let current = job.attempt
            lock.unlock()
            logger.debug("[Transfer] \(tag) download stale attempt=\(attempt) ended (\(outcome)) while attempt \(current) is current, dropped")
            return
        }
        switch job.state {
        case .finished, .paused(alive: false):
            // Cancelled, or stopped by a pause: a resume starts again.
            let state = job.state
            lock.unlock()
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) ended (\(outcome)) while \(state), dropped")
            return
        default:
            // A task left suspended long enough can be timed out by the system; that is a
            // failed download.
            job.state = .finished
            downloads[ObjectIdentifier(job.taskInfo)] = nil
        }
        let tasks = [job.taskInfo] + job.joined
        lock.unlock()
        // Failures are reported at the end, once, by `AttachmentTransfer`: debug here.
        switch result {
        case .success(let file):
            // Checked before anything replaces the task's event: `updateLocalFileLocation`
            // would hide that the task ended, and the success would be reported over it.
            let live = tasks.filter { !$0.isTerminal }
            guard !live.isEmpty else {
                logger.debug("[Transfer] \(tag) download attempt=\(attempt) succeeded after the task already ended (\(Self.describe(job.taskInfo.event))): result dropped")
                return
            }
            if !FileManager.default.fileExists(atPath: file.path) {
                logger.warn("[Transfer] \(tag) download attempt=\(attempt) transport reported success but \(file.lastPathComponent) does not exist")
            }
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) running -> finished (success) size=\(TransferLog.sizeText(file)) decrypted=\(job.request.encryptionInfo != nil)")
            for taskInfo in live {
                if job.request.encryptionInfo != nil {
                    taskInfo.didDecryptDownload = true
                }
                taskInfo.updateLocalFileLocation(newPath: file.path)
            }
            report(live, .successURI(job.request.url))
        case .failure(let error):
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) running -> finished (failure): \(TransferLog.describe(error))")
            report(tasks, .failure(error))
        case .interrupted(let error):
            logger.debug("[Transfer] \(tag) download attempt=\(attempt) running -> finished (interrupted): \(TransferLog.describe(error))")
            report(tasks, .failure(error), interrupted: true)
        }
    }

    private func pause(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        lock.lock()
        guard case .running = job.state else {
            let state = job.state
            lock.unlock()
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) pause ignored while \(state)")
            return
        }
        lock.unlock()
        let alive = transport.pause(operationId: job.request.operationId)
        lock.lock()
        guard case .running = job.state else {
            let state = job.state
            lock.unlock()
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) pause raced to \(state), ignored")
            return
        }
        job.state = .paused(alive: alive)
        lock.unlock()
        logger.info("[Transfer] \(tag) download attempt=\(attempt(of: job)) running -> paused(alive: \(alive))\(alive ? "" : ", task cancelled")")
        if !alive {
            job.task?.cancel()
        }
    }

    private func resume(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        lock.lock()
        guard case .paused(let alive) = job.state else {
            let state = job.state
            lock.unlock()
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) resume ignored while \(state)")
            return
        }
        if alive {
            job.state = .running
        }
        lock.unlock()
        if alive, transport.resume(operationId: job.request.operationId) {
            logger.info("[Transfer] \(tag) download attempt=\(attempt(of: job)) paused -> running (resumed the live invocation)")
            return
        }
        lock.lock()
        if case .finished = job.state {
            // Cancelled while the transport was asked to resume: it stays cancelled.
            lock.unlock()
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) cancelled during the resume, not restarted")
            return
        }
        job.state = .paused(alive: false)
        lock.unlock()
        logger.info("[Transfer] \(tag) download attempt=\(attempt(of: job)) \(alive ? "transport could not resume the invocation" : "no live invocation"), starting a new attempt")
        start(job)
    }

    private func cancel(_ job: DownloadJob) {
        let tag = job.taskInfo.logTag
        lock.lock()
        if case .finished = job.state {
            lock.unlock()
            logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) cancel ignored: already finished")
            return
        }
        let previous = job.state
        job.state = .finished
        downloads[ObjectIdentifier(job.taskInfo)] = nil
        lock.unlock()
        logger.debug("[Transfer] \(tag) download attempt=\(attempt(of: job)) \(previous) -> finished (cancelled)")
        transport.cancel(operationId: job.request.operationId)
        job.task?.cancel()
        report(tasks(of: job), .failure(URLError(.cancelled)))
    }

    // MARK: Reporting

    /// The job's attempt, read under the lock, for a log line written outside it.
    private func attempt(of job: UploadJob) -> Int {
        lock.lock(); defer { lock.unlock() }
        return job.attempt
    }

    private func attempt(of job: DownloadJob) -> Int {
        lock.lock(); defer { lock.unlock() }
        return job.attempt
    }

    /// The job's own task and every task that joined it.
    private func tasks(of job: UploadJob) -> [SCTDataSessionTaskInfo] {
        lock.lock(); defer { lock.unlock() }
        return [job.taskInfo] + job.joined
    }

    private func tasks(of job: DownloadJob) -> [SCTDataSessionTaskInfo] {
        lock.lock(); defer { lock.unlock() }
        return [job.taskInfo] + job.joined
    }

    private func joined(of job: UploadJob) -> [SCTDataSessionTaskInfo] {
        lock.lock(); defer { lock.unlock() }
        return job.joined
    }

    private func isTerminal(_ taskInfo: SCTDataSessionTaskInfo) -> Bool {
        taskInfo.isTerminal
    }

    private func report(_ tasks: [SCTDataSessionTaskInfo], _ event: SCTDataSessionTaskInfo.Event, interrupted: Bool = false) {
        for taskInfo in tasks {
            if interrupted, !taskInfo.isTerminal {
                taskInfo.wasInterrupted = true
            }
            report(taskInfo, event)
        }
    }

    /// Reports the end of a transfer once: a task already ended elsewhere (failed on network
    /// loss) is left alone.
    func report(_ taskInfo: SCTDataSessionTaskInfo, _ event: SCTDataSessionTaskInfo.Event) {
        guard !isTerminal(taskInfo) else {
            logger.debug("[Transfer] \(taskInfo.logTag) \(taskInfo.transferType) report of \(Self.describe(event)) dropped: the task already ended with \(Self.describe(taskInfo.event))")
            return
        }
        switch event {
        case .failure(let error):
            taskInfo.failure(error: error)
        case .successURI(let uri):
            taskInfo.success(origin: uri)
        case .successURL(let url):
            taskInfo.success(origin: url)
        case .updateProgress, .updateLocalFileURL:
            break
        }
    }
}

// MARK: - Diagnostics

extension TransportDataSession {
    static func describe<T>(_ result: FileTransferResult<T>) -> String {
        switch result {
        case .success:
            return "success"
        case .failure(let error):
            return "failure \(TransferLog.describe(error))"
        case .interrupted(let error):
            return "interrupted \(TransferLog.describe(error))"
        }
    }

    /// An event without its url: a success carries the remote reference.
    static func describe(_ event: SCTDataSessionTaskInfo.Event?) -> String {
        switch event {
        case .none:
            return "no event"
        case .updateLocalFileURL:
            return "updateLocalFileURL"
        case .updateProgress(let progress):
            return "updateProgress(\(progress))"
        case .failure(let error):
            return "failure(\(TransferLog.describe(error)))"
        case .successURI(let uri):
            return "successURI(\(TransferLog.redact(uri)))"
        case .successURL(let url):
            return "successURL(\(TransferLog.redact(url)))"
        }
    }
}

/// Logs progress at 25 / 50 / 75 / 100 % only, never per chunk.
private final class ProgressMilestones {
    private let lock = NSLock()
    private var logged = 0

    /// The milestone `progress` just crossed, once per attempt's climb.
    func crossed(_ progress: Double) -> Int? {
        let quarter = min(4, max(0, Int(progress * 4)))
        lock.lock(); defer { lock.unlock() }
        if quarter < logged {
            // A new attempt starts from the beginning again.
            logged = quarter
            return nil
        }
        guard quarter > logged else { return nil }
        logged = quarter
        return quarter * 25
    }
}

// MARK: - Jobs

private final class UploadJob {
    enum State {
        /// In the queue; `alive` when a paused invocation is there to resume.
        case waiting(alive: Bool)
        case preparing
        case uploading
        case paused(alive: Bool)
        case finished
    }

    let attachment: ChatMessage.Attachment
    let taskInfo: SCTDataSessionTaskInfo
    let operationId: String
    let videoProcessInfo = SCVideoProcessInfo()
    /// Guarded by the session's lock, like `attempt`.
    var state = State.waiting(alive: false)
    /// Tasks that started the same operation while this job ran: they get its events.
    /// Guarded by the session's lock.
    var joined = [SCTDataSessionTaskInfo]()

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }
    /// Bumped by every new attempt, so a callback of an earlier one is ignored.
    var attempt = 0
    var task: Task<Void, Never>?
    private let milestones = ProgressMilestones()

    func progressMilestone(_ progress: Double) -> Int? {
        milestones.crossed(progress)
    }

    init(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo, operationId: String) {
        self.attachment = attachment
        self.taskInfo = taskInfo
        self.operationId = operationId
    }

    /// Stops preparation and the current invocation. To the transport this is an interruption,
    /// not an abandonment.
    func stopWork() {
        videoProcessInfo.cancel()
        task?.cancel()
    }
}

private final class DownloadJob {
    enum State {
        case running
        case paused(alive: Bool)
        case finished
    }

    let request: FileDownloadRequest
    let taskInfo: SCTDataSessionTaskInfo
    var state = State.running
    /// Tasks that started the same operation while this job ran: they get its events.
    /// Guarded by the session's lock.
    var joined = [SCTDataSessionTaskInfo]()

    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }
    var attempt = 0
    var task: Task<Void, Never>?
    private let milestones = ProgressMilestones()

    func progressMilestone(_ progress: Double) -> Int? {
        milestones.crossed(progress)
    }

    init(request: FileDownloadRequest, taskInfo: SCTDataSessionTaskInfo) {
        self.request = request
        self.taskInfo = taskInfo
    }
}
