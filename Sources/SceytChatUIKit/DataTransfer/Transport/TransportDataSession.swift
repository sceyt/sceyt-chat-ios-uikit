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
/// Safe to share between threads: its transfers live in `board`, changed one locked step at a
/// time; its configuration (`environment`, `stagingDirectory`, the hooks) is set before the
/// first transfer and only read after.
open class TransportDataSession: NSObject, SCTDataSession, @unchecked Sendable {

    public let transport: FileTransferTransport

    /// The jobs, the upload queue and its slots, and each job's state: changed only through
    /// `board.withState`, one locked step at a time.
    let board = JobBoard()

    /// Whether this process is an app extension, which resizes images with less memory.
    open var isAppExtension: Bool { Bundle.main.isAppExtension }

    /// How video posters go up and come down.
    var thumbnailTransfer = DefaultThumbnailTransfer()

    /// The dependencies preparation uses (video export, image resize, storage). Set it before
    /// the first upload.
    public var environment = TransferEnvironment.components

    /// Test hooks, run as an upload attempt is about to take its slot and as a download
    /// attempt is about to start: what happens to the transfer meanwhile is what they test.
    var willBeginUpload: ((SCTDataSessionTaskInfo) -> Void)?
    var willStartDownload: ((SCTDataSessionTaskInfo) -> Void)?

    /// Decrypts what the transport downloads for an encrypted attachment.
    let encryptedDownloader: EncryptedFileDownloader

    /// Runs the uploads (UploadCoordinator.swift). Set once, in `init`.
    private(set) var uploads: UploadCoordinator!
    /// Runs the downloads (DownloadCoordinator.swift). Set once, in `init`.
    private(set) var downloads: DownloadCoordinator!

    /// Where encrypted downloads keep their sessions (no keys): Application Support, so a
    /// decryption resumes after a relaunch.
    static var encryptedDownloadSessionsDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("SceytChatUIKit/download-sessions", isDirectory: true)
    }

    /// One for every session: they share the sessions directory, and a purge must see every
    /// session's running downloads.
    static let sharedEncryptedDownloader = EncryptedFileDownloader(directory: encryptedDownloadSessionsDirectory)

    /// How long an encrypted download nobody tried again keeps its temporary files.
    static let staleDownloadSessionAge: TimeInterval = 7 * 24 * 60 * 60

    public init(transport: FileTransferTransport) {
        self.transport = transport
        encryptedDownloader = Self.sharedEncryptedDownloader
        super.init()
        uploads = UploadCoordinator(session: self)
        downloads = DownloadCoordinator(session: self)
        let staging = self.staging
        let downloader = encryptedDownloader
        DispatchQueue.global(qos: .utility).async {
            staging.purgeStale()
            downloader.purgeStale(olderThan: Self.staleDownloadSessionAge)
        }
    }

    open var supportsAttachmentEncryption: Bool { true }

    /// How long an upload waits for the checksum provider before it uploads anyway.
    var checksumTimeout: TimeInterval = 60

    /// How many uploads run at once; the rest wait in order. One by default: a message is
    /// sent when its upload lands, so parallel uploads can send messages out of the order
    /// they were written in (a small photo overtaking an earlier video). Raise it where
    /// that order does not matter, or is restored elsewhere.
    open var maxConcurrentUploads: Int { 1 }

    /// Whether an upload first asks the checksum table for an object already stored.
    open var checksumsBeforeUpload: Bool {
        environment.preventsDuplicateUploads()
    }

    // MARK: Identity

    /// Names an upload across attempts and relaunches. Only an outgoing attachment has a
    /// `tid`; without one nothing an attempt saves can be found again.
    open func uploadOperationId(for attachment: ChatMessage.Attachment) -> String {
        attachment.tid != 0 ? "upload-\(attachment.tid)" : "upload-\(UUID().uuidString)"
    }

    /// The server accepted `message`: its uploads' results are final, and what the transport
    /// kept to report them again goes. Only attachments with a `tid` have an operation that
    /// can be found again.
    open func messageSent(_ message: ChatMessage) {
        for attachment in message.attachments ?? [] where attachment.tid != 0 && attachment.type != "link" {
            transport.uploadDelivered(operationId: uploadOperationId(for: attachment))
        }
    }

    /// HTTP headers for an attachment's download request. None by default; a transport that
    /// needs per-request values read at send time (a token that may be refreshed) adds them
    /// itself.
    open func downloadHeaders(for attachment: ChatMessage.Attachment, message: ChatMessage) -> [String: String] {
        [:]
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

    /// Where this session keeps the files it transfers. Replace it to store them elsewhere,
    /// rather than overriding the methods below. Set it before the first transfer.
    public var fileStore: AttachmentFileStore = FileStorage.default

    /// Moves (or copies) `path` into storage and returns where it is now: `fileStore`'s.
    /// Kept for subclasses written before `fileStore`; new code sets `fileStore` instead.
    open func storeFile(atPath path: String, transferId: String, fileName: String?) -> String {
        fileStore.store(fileAt: path, transferId: transferId, fileName: fileName)
    }

    /// Removes a file from storage: `fileStore`'s. Kept like `storeFile`.
    open func removeFile(atPath path: String) {
        fileStore.remove(fileAt: path)
    }

    /// Moves the thumbnails of a stored file along with it: `fileStore`'s. Kept like `storeFile`.
    open func updateThumbnailPath(transferId: String, filePath: String) {
        fileStore.updateThumbnailPath(transferId: transferId, filePath: filePath)
    }

    /// Where a download's plaintext goes, the place `getFilePath` finds it afterwards.
    open func downloadDestination(for attachment: ChatMessage.Attachment) -> URL? {
        guard let string = attachment.url, let url = URL(string: string) else {
            logger.debug("[Transfer] \(TransferLog.currentTag) no download destination: url missing or unparsable (\(TransferLog.redact(attachment.url))) \(attachment.transferLogDescription)")
            return nil
        }
        let transferId = url.deletingLastPathComponent().lastPathComponent
        return fileStore.downloadDestination(transferId: transferId, fileName: attachment.name)
    }

    /// Prepared files waiting for their upload to land, one folder per operation.
    open var stagingDirectory: URL {
        TransferDirectories.cachesOrTemporary().appendingPathComponent("upload-staging", isDirectory: true)
    }

    /// The staged files of uploads, under `stagingDirectory` (read each time: a subclass
    /// may override it).
    var staging: UploadStaging {
        UploadStaging(directory: stagingDirectory)
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
        thumbnailTransfer.upload(fileUrl: fileUrl, completion: completion)
    }

    open func downloadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        origin: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        thumbnailTransfer.download(origin: origin, completion: completion)
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
        // A second start of an upload still running joins it: two jobs of one operation would
        // share its staging folder and the transport's record, and a cancel of one would end
        // the other's transfer.
        let joinedRunning: (job: UploadJob, state: UploadJob.State, attempt: Int)? = board.withState { jobs in
            guard let running = jobs.uploads.values.first(where: { $0.operationId == job.operationId && !$0.isFinished }) else {
                jobs.uploads[ObjectIdentifier(taskInfo)] = job
                return nil
            }
            running.joined.append(taskInfo)
            return (running, running.state, running.attempt)
        }
        if let joinedRunning {
            let (running, state, attempt) = joinedRunning
            taskInfo.attempts = attempt
            logger.info("[Transfer] \(tag) upload started again while attempt \(attempt) is \(state): joins it, no second transfer \(attachment.transferLogDescription)")
            taskInfo.onAction = actions(of: running)
            if case .paused = state {
                uploads.resume(running)
            }
            return
        }
        if attachment.tid == 0 {
            logger.warn("[Transfer] \(tag) upload has no tid: a retry or relaunch cannot find what this attempt saves \(attachment.transferLogDescription)")
        }
        logger.debug("[Transfer] \(tag) upload queued encryption=\(taskInfo.encryption) source=\(TransferLog.size(path: attachment.filePath)) \(attachment.transferLogDescription)")
        taskInfo.onAction = actions(of: job)
        uploads.enqueue(job)
    }

    func actions(of job: UploadJob) -> (SCTDataSessionTaskInfo.Action) -> Void {
        { [weak self, weak job] action in
            guard let self, let job else { return }
            switch action {
            case .stop:
                self.uploads.pause(job)
            case .resume:
                self.uploads.resume(job)
            case .cancel:
                self.uploads.cancel(job)
            }
        }
    }

    func actions(of job: DownloadJob) -> (SCTDataSessionTaskInfo.Action) -> Void {
        { [weak self, weak job] action in
            guard let self, let job else { return }
            switch action {
            case .stop:
                self.downloads.pause(job)
            case .resume:
                self.downloads.resume(job)
            case .cancel:
                self.downloads.cancel(job)
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
        let encryption = (taskInfo.encryption == .required ? taskInfo.downloadEncryption?.fileInfo : nil).map {
            // The size the sender sent: decryption verifies the object holds exactly that.
            FileDownloadEncryption(info: $0, trustedPlaintextSize: attachment.uploadedFileSize > 0 ? Int64(attachment.uploadedFileSize) : nil)
        }
        let request = FileDownloadRequest(
            operationId: taskInfo.operationId,
            url: url,
            destinationFile: destination,
            context: AttachmentTransferContext(message: taskInfo.message, attachment: attachment),
            headers: downloadHeaders(for: attachment, message: taskInfo.message)
        )
        let job = DownloadJob(request: request, encryption: encryption, taskInfo: taskInfo)
        if taskInfo.encryption == .required, encryption == nil {
            // Fails closed later: the transport stores ciphertext and the gate rejects it.
            logger.warn("[Encryption] \(tag) download must be decrypted but has no enc; the request goes out without it \(attachment.transferLogDescription)")
        }
        // A second start of a download still running joins it: two invocations of one
        // operation would write the same destination, and only one could be controlled.
        let joinedRunning: (job: DownloadJob, state: DownloadJob.State, attempt: Int)? = board.withState { jobs in
            guard let running = jobs.downloads.values.first(where: { $0.request.operationId == request.operationId && !$0.isFinished }) else {
                jobs.downloads[ObjectIdentifier(taskInfo)] = job
                return nil
            }
            running.joined.append(taskInfo)
            return (running, running.state, running.attempt)
        }
        if let joinedRunning {
            let (running, state, attempt) = joinedRunning
            taskInfo.attempts = attempt
            logger.info("[Transfer] \(tag) download started again while attempt \(attempt) is \(state): joins it, no second transfer \(attachment.transferLogDescription)")
            taskInfo.onAction = actions(of: running)
            if case .paused = state {
                downloads.resume(running)
            }
            return
        }
        logger.debug("[Transfer] \(tag) download queued encrypted=\(encryption != nil) trustedSize=\(encryption?.trustedPlaintextSize.map { "\($0) B" } ?? "-") url=\(TransferLog.redact(url)) destinationExists=\(FileManager.default.fileExists(atPath: destination.path)) \(attachment.transferLogDescription)")
        taskInfo.onAction = actions(of: job)
        downloads.start(job)
    }

    /// Abandons the uploads of `attachments`, running or only saved by the transport (after a
    /// relaunch nothing runs, but a remote multipart upload may still be open).
    open func cancel(attachments: [ChatMessage.Attachment]) {
        for attachment in attachments where attachment.tid != 0 {
            let job = board.withState { jobs in jobs.uploads.values.first { $0.attachment.tid == attachment.tid } }
            if let job {
                logger.info("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) abandoned by cancel(attachments:) \(attachment.transferLogDescription)")
                uploads.cancel(job)
            } else {
                let operationId = uploadOperationId(for: attachment)
                logger.info("[Transfer] xfer=\(operationId) upload has no live job: abandoning what the transport saved \(attachment.transferLogDescription)")
                transport.cancel(operationId: operationId)
                staging.discard(operationId: operationId)
            }
        }
    }

    /// Stops every transfer without abandoning any (the network went away): each task fails
    /// with `error`, and the transport keeps what a later attempt can continue.
    open func interruptTransfers(error: Error) {
        let (uploadJobs, downloadJobs) = board.withState { jobs -> ([UploadJob], [DownloadJob]) in
            let uploadJobs = Array(jobs.uploads.values)
            let downloadJobs = Array(jobs.downloads.values)
            uploadJobs.forEach { $0.state = .finished }
            downloadJobs.forEach { $0.state = .finished }
            jobs = JobBoard.Jobs()
            return (uploadJobs, downloadJobs)
        }
        logger.warn("[Transfer] interrupting \(uploadJobs.count) upload(s) and \(downloadJobs.count) download(s): \(TransferLog.describe(error))")
        for job in uploadJobs {
            logger.debug("[Transfer] \(job.taskInfo.logTag) upload attempt=\(attempt(of: job)) -> finished (interrupted)")
            job.stopWork()
            report(tasks(of: job), .failure(error), interrupted: true)
        }
        for job in downloadJobs {
            logger.debug("[Transfer] \(job.taskInfo.logTag) download attempt=\(attempt(of: job)) -> finished (interrupted)")
            job.cancelTask()
            report(tasks(of: job), .failure(error), interrupted: true)
        }
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
        try await UploadPreparer(staging: staging, environment: environment, isAppExtension: isAppExtension)
            .prepare(attachment, taskInfo: taskInfo, operationId: operationId, videoProcessInfo: videoProcessInfo)
    }

    func prepareUploadFile(_ job: UploadJob, videoProcessInfo: SCVideoProcessInfo) async throws -> PreparedUploadFile {
        try await prepareUploadFile(
            for: job.attachment,
            taskInfo: job.taskInfo,
            operationId: job.operationId,
            videoProcessInfo: videoProcessInfo
        )
    }

    /// The upload landed: the staged file becomes the attachment's, and an image's original
    /// goes (the resized copy is what was sent).
    func adopt(_ staged: URL, job: UploadJob, tasks: [SCTDataSessionTaskInfo]) {
        let tag = job.taskInfo.logTag
        guard FileManager.default.fileExists(atPath: staged.path) else {
            logger.warn("[Transfer] \(tag) upload landed but its staged file is gone: the attachment keeps its original file")
            return
        }
        let original = job.attachment.filePath
        let transferId = UUID().uuidString
        // The staging folder is deleted next, so adopting a file that was not stored would
        // leave the attachment with no file, and an image's original would be deleted too.
        let path: String
        do {
            path = try AttachmentFileStoreResult.check(
                storeFile(atPath: staged.path, transferId: transferId, fileName: staged.lastPathComponent),
                source: staged.path
            )
        } catch {
            logger.error("[Transfer] \(tag) upload landed but its staged file could not be stored (\(error)): the attachment keeps its original file \(job.attachment.transferLogDescription)")
            return
        }
        logger.debug("[Transfer] \(tag) upload staged file adopted as the attachment's file")
        tasks.forEach { $0.updateLocalFileLocation(newPath: path) }
        updateThumbnailPath(transferId: transferId, filePath: path)
        if job.attachment.kind == .image, let original, original != path, original != staged.path {
            removeFile(atPath: original)
        }
    }

    static func fileSize(_ url: URL?) -> Int64? {
        guard let url, let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else { return nil }
        return Int64(size)
    }

    // MARK: Reporting

    /// The job's attempt, read under the lock, for a log line written outside it.
    func attempt(of job: some TransferJob) -> Int {
        board.withState { _ in job.attempt }
    }

    /// The job's own task and every task that joined it.
    func tasks(of job: some TransferJob) -> [SCTDataSessionTaskInfo] {
        board.withState { _ in [job.taskInfo] + job.joined }
    }

    func joined(of job: UploadJob) -> [SCTDataSessionTaskInfo] {
        board.withState { _ in job.joined }
    }

    func isTerminal(_ taskInfo: SCTDataSessionTaskInfo) -> Bool {
        taskInfo.isTerminal
    }

    func report(_ tasks: [SCTDataSessionTaskInfo], _ event: SCTDataSessionTaskInfo.Event, interrupted: Bool = false) {
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
        guard taskInfo.endIfLive(with: event) else {
            logger.debug("[Transfer] \(taskInfo.logTag) \(taskInfo.transferType) report of \(Self.describe(event)) dropped: the task already ended with \(Self.describe(taskInfo.event))")
            return
        }
    }
}

// MARK: - Diagnostics

extension TransportDataSession {
    static func describe<T: Sendable>(_ result: FileTransferResult<T>) -> String {
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
