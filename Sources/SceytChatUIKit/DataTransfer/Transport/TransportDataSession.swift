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

    open func downloadOperationId(for attachment: ChatMessage.Attachment) -> String {
        "download-\(AttachmentTransfer.transferIdentity(of: attachment))"
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
        guard let string = attachment.url, let url = URL(string: string) else { return nil }
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
        let job = UploadJob(
            attachment: attachment,
            taskInfo: taskInfo,
            operationId: uploadOperationId(for: attachment)
        )
        lock.lock()
        uploads[ObjectIdentifier(taskInfo)] = job
        lock.unlock()
        taskInfo.onAction = { [weak self, weak job] action in
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
        enqueue(job)
    }

    open func download(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        guard let url = attachment.url, !url.isEmpty,
              let destination = downloadDestination(for: attachment)
        else {
            logger.error("[Attachment] \(type(of: self)).download: unusable url, download not started \(attachment.description)")
            Task { self.report(taskInfo, .failure(FileTransferError.invalidRequest)) }
            return
        }
        let request = FileDownloadRequest(
            operationId: downloadOperationId(for: attachment),
            url: url,
            destinationFile: destination,
            encryptionInfo: taskInfo.encryption == .required ? taskInfo.downloadEncryption?.fileInfo : nil,
            context: AttachmentTransferContext(message: taskInfo.message, attachment: attachment)
        )
        let job = DownloadJob(request: request, taskInfo: taskInfo)
        lock.lock()
        downloads[ObjectIdentifier(taskInfo)] = job
        lock.unlock()
        taskInfo.onAction = { [weak self, weak job] action in
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
                cancel(job)
            } else {
                let operationId = uploadOperationId(for: attachment)
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
        for job in uploadJobs {
            job.stopWork()
            report(job.taskInfo, .failure(error))
        }
        for job in downloadJobs {
            job.task?.cancel()
            report(job.taskInfo, .failure(error))
        }
    }

    // MARK: Upload queue

    private func enqueue(_ job: UploadJob) {
        lock.lock()
        guard active == nil else {
            waiting.append(job)
            lock.unlock()
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
        if let next {
            begin(next)
        }
    }

    /// `job` holds the slot: continue its paused invocation, or start a new attempt.
    private func begin(_ job: UploadJob) {
        lock.lock()
        guard case .waiting(let alive) = job.state else {
            lock.unlock()
            releaseSlot(of: job)
            return
        }
        if alive {
            job.state = .uploading
            lock.unlock()
            if transport.resume(operationId: job.operationId) {
                return
            }
            lock.lock()
            guard case .uploading = job.state else {
                lock.unlock()
                return
            }
        }
        job.attempt += 1
        let attempt = job.attempt
        job.state = .preparing
        let previous = job.task
        lock.unlock()
        previous?.cancel()
        job.task = Task { [weak self] in
            await self?.run(job, attempt: attempt)
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
        if checksumsBeforeUpload {
            let stored = await withCheckedContinuation { continuation in
                taskInfo.startChecksum { continuation.resume(returning: $0) }
            }
            // A stored copy was reported by the checksum itself, and so was its failure.
            if stored || isTerminal(taskInfo) {
                finish(job, attempt: attempt)
                return
            }
        }
        guard isCurrent(job, attempt: attempt) else { return }

        let prepared: PreparedUploadFile
        do {
            prepared = try await prepareUploadFile(job)
        } catch {
            guard isCurrent(job, attempt: attempt) else { return }
            logger.errorIfNotNil(error, "[Attachment] upload preparation failed \(job.attachment.description)")
            finish(job, attempt: attempt)
            report(taskInfo, .failure(error))
            return
        }
        guard startUploading(job, attempt: attempt) else { return }

        let type: FileUploadType = taskInfo.encryption == .required ? .encrypted : .plain
        let fileName = job.attachment.name?.isEmpty == false ? job.attachment.name! : prepared.file.lastPathComponent
        let request = FileUploadRequest(
            operationId: job.operationId,
            sourceFile: prepared.file,
            fileName: fileName,
            mimeType: UTType(filenameExtension: prepared.file.pathExtension)?.preferredMIMEType,
            context: AttachmentTransferContext(message: taskInfo.message, attachment: job.attachment),
            type: type
        )
        let result = await transport.upload(request) { [weak self, weak job] progress in
            guard let self, let job, self.isUploading(job, attempt: attempt) else { return }
            taskInfo.updateProgress(progress)
        }
        handle(result, of: job, attempt: attempt, prepared: prepared, type: type)
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
        lock.lock()
        guard job.attempt == attempt else {
            lock.unlock()
            return
        }
        switch (result, job.state) {
        case (_, .finished):
            lock.unlock()
            return
        case (.success, _):
            // Landed, even while paused: the file is stored.
            break
        case (_, .paused):
            // The paused invocation ended without the file: a resume starts a new attempt.
            job.state = .paused(alive: false)
            lock.unlock()
            return
        case (_, .waiting):
            job.state = .waiting(alive: false)
            lock.unlock()
            return
        default:
            break
        }
        lock.unlock()
        finish(job, attempt: attempt)

        let taskInfo = job.taskInfo
        switch result {
        case .success(let uploaded):
            if type == .encrypted, uploaded.encryptionInfo == nil {
                // Encrypted bytes without their key could never be opened.
                report(taskInfo, .failure(AttachmentEncryptionError.encryptionBypassed))
                return
            }
            if prepared.isStaged {
                adopt(prepared.file, job: job)
            }
            discardStaged(operationId: job.operationId)
            taskInfo.uploadedEncryption = uploaded.encryptionInfo
            if type == .encrypted {
                taskInfo.uploadedPlaintextSize = Self.fileSize(prepared.file) ?? Self.fileSize(job.attachment.filePath.map { URL(fileURLWithPath: $0) })
            }
            report(taskInfo, .successURI(uploaded.remoteReference))
        case .failure(let error), .interrupted(let error):
            // The staged file stays: the next attempt sends it again.
            report(taskInfo, .failure(error))
        }
    }

    /// The attempt is over: the job leaves the queue and the session.
    private func finish(_ job: UploadJob, attempt: Int) {
        lock.lock()
        guard job.attempt == attempt else {
            lock.unlock()
            return
        }
        job.state = .finished
        uploads[ObjectIdentifier(job.taskInfo)] = nil
        lock.unlock()
        releaseSlot(of: job)
    }

    private func pause(_ job: UploadJob) {
        lock.lock()
        switch job.state {
        case .waiting(let alive):
            waiting.removeAll { $0 === job }
            job.state = .paused(alive: alive)
            lock.unlock()
        case .preparing:
            job.state = .paused(alive: false)
            lock.unlock()
            job.stopWork()
            releaseSlot(of: job)
        case .uploading:
            lock.unlock()
            let alive = transport.pause(operationId: job.operationId)
            lock.lock()
            guard case .uploading = job.state else {
                lock.unlock()
                return
            }
            job.state = .paused(alive: alive)
            lock.unlock()
            if !alive {
                job.stopWork()
            }
            releaseSlot(of: job)
        case .paused, .finished:
            lock.unlock()
        }
    }

    private func resume(_ job: UploadJob) {
        lock.lock()
        guard case .paused(let alive) = job.state else {
            lock.unlock()
            return
        }
        job.state = .waiting(alive: alive)
        lock.unlock()
        enqueue(job)
    }

    private func cancel(_ job: UploadJob) {
        lock.lock()
        if case .finished = job.state {
            lock.unlock()
            return
        }
        job.state = .finished
        waiting.removeAll { $0 === job }
        uploads[ObjectIdentifier(job.taskInfo)] = nil
        lock.unlock()
        transport.cancel(operationId: job.operationId)
        job.stopWork()
        discardStaged(operationId: job.operationId)
        releaseSlot(of: job)
    }

    // MARK: Preparation

    /// The file to upload for `attachment`: the file staged by an earlier attempt of the same
    /// operation, or a new one. Images are resized, videos exported, folders zipped; any other
    /// file is moved into storage.
    open func prepareUploadFile(
        for attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo,
        operationId: String,
        videoProcessInfo: SCVideoProcessInfo
    ) async throws -> PreparedUploadFile {
        guard var filePath = attachment.filePath else {
            throw TransportDataSessionError.missingSourceFile
        }
        if attachment.type == "image" || attachment.type == "video",
           let staged = stagedFile(operationId: operationId) {
            // An export or resize would make different bytes than the ones already sent.
            logger.verbose("[Attachment] upload \(operationId) sends the file an earlier attempt prepared")
            return PreparedUploadFile(file: staged, isStaged: true)
        }
        taskInfo.updateProgress(0.01)
        switch attachment.type {
        case "video":
            switch await Components.videoProcessor.export(from: filePath, processInfo: videoProcessInfo) {
            case .success(let exported):
                try Task.checkCancellation()
                return PreparedUploadFile(file: try stage(exported, operationId: operationId, fileName: exported.lastPathComponent), isStaged: true)
            case .failure(let error):
                logger.info("[Attachment] video export failed (\((error as NSError).domain)/\((error as NSError).code)), uploading the original")
            }
        case "image":
            let config = SceytChatUIKit.shared.config.imageAttachmentResizeConfig
            var jpeg: Data?
            if Bundle.main.isAppExtension {
                jpeg = Components.imageBuilder.lowMemory_resizeImage(fileUrl: URL(fileURLWithPath: filePath), maxPixelSize: config.dimensionThreshold)?
                    .jpegData(compressionQuality: config.compressionQuality)
            } else if let builder = Components.imageBuilder.init(imageUrl: URL(fileURLWithPath: filePath)),
                      !builder.imageSize.isNan {
                jpeg = try? builder.resize(max: config.dimensionThreshold).jpegData(compressionQuality: config.compressionQuality)
            }
            try Task.checkCancellation()
            if let jpeg,
               let resized = Components.storage.storeInTemporaryDirectory(data: jpeg, filename: attachment.name ?? UUID().uuidString) {
                return PreparedUploadFile(file: try stage(resized, operationId: operationId, fileName: resized.lastPathComponent), isStaged: true)
            }
        case "file":
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                let zip = try await Components.storage.makeUploadingUrl(directoryUrl: URL(fileURLWithPath: filePath))
                try Task.checkCancellation()
                taskInfo.updateLocalFileLocation(newLocation: zip)
                filePath = zip.path
            } else {
                filePath = storeFile(atPath: filePath, transferId: UUID().uuidString, fileName: attachment.name)
                taskInfo.updateLocalFileLocation(newPath: filePath)
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
    private func adopt(_ staged: URL, job: UploadJob) {
        guard FileManager.default.fileExists(atPath: staged.path) else { return }
        let original = job.attachment.filePath
        let transferId = UUID().uuidString
        let path = storeFile(atPath: staged.path, transferId: transferId, fileName: staged.lastPathComponent)
        job.taskInfo.updateLocalFileLocation(newPath: path)
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

    private func stage(_ file: URL, operationId: String, fileName: String) throws -> URL {
        let fileManager = FileManager.default
        let folder = stagingFolder(operationId: operationId)
        try? fileManager.removeItem(at: folder)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let staged = folder.appendingPathComponent(fileName.isEmpty ? "file" : fileName)
        try fileManager.moveItem(at: file, to: staged)
        return staged
    }

    private func discardStaged(operationId: String) {
        try? FileManager.default.removeItem(at: stagingFolder(operationId: operationId))
    }

    /// How long a staged file nobody uploaded or abandoned is kept.
    static let staleStagingAge: TimeInterval = 7 * 24 * 60 * 60

    private static func purgeStaleStaging(in directory: URL) {
        let fileManager = FileManager.default
        let cutoff = Date().addingTimeInterval(-staleStagingAge)
        let folders = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for folder in folders {
            let modified = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff {
                try? fileManager.removeItem(at: folder)
            }
        }
    }

    static func fileSize(_ url: URL?) -> Int64? {
        guard let url, let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize else { return nil }
        return Int64(size)
    }

    // MARK: Downloads

    private func start(_ job: DownloadJob) {
        lock.lock()
        if case .finished = job.state {
            lock.unlock()
            return
        }
        job.attempt += 1
        let attempt = job.attempt
        job.state = .running
        let previous = job.task
        lock.unlock()
        previous?.cancel()
        let taskInfo = job.taskInfo
        let encrypted = job.request.encryptionInfo != nil
        job.task = Task { [weak self] in
            guard let self else { return }
            let result = await self.transport.download(job.request) { [weak self, weak job] progress in
                guard let self, let job, self.isRunning(job, attempt: attempt) else { return }
                // Not done when the last byte arrives: it still has to be verified and
                // decrypted, so the bar stops short of full until then.
                taskInfo.updateProgress(encrypted ? min(progress, 0.99) : progress)
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
        lock.lock()
        guard job.attempt == attempt else {
            lock.unlock()
            return
        }
        switch job.state {
        case .finished, .paused(alive: false):
            // Cancelled, or stopped by a pause: a resume starts again.
            lock.unlock()
            return
        default:
            // A task left suspended long enough can be timed out by the system; that is a
            // failed download.
            job.state = .finished
            downloads[ObjectIdentifier(job.taskInfo)] = nil
        }
        lock.unlock()
        let taskInfo = job.taskInfo
        switch result {
        case .success(let file):
            if job.request.encryptionInfo != nil {
                taskInfo.didDecryptDownload = true
            }
            taskInfo.updateLocalFileLocation(newPath: file.path)
            report(taskInfo, .successURI(job.request.url))
        case .failure(let error), .interrupted(let error):
            report(taskInfo, .failure(error))
        }
    }

    private func pause(_ job: DownloadJob) {
        lock.lock()
        guard case .running = job.state else {
            lock.unlock()
            return
        }
        lock.unlock()
        let alive = transport.pause(operationId: job.request.operationId)
        lock.lock()
        guard case .running = job.state else {
            lock.unlock()
            return
        }
        job.state = .paused(alive: alive)
        lock.unlock()
        if !alive {
            job.task?.cancel()
        }
    }

    private func resume(_ job: DownloadJob) {
        lock.lock()
        guard case .paused(let alive) = job.state else {
            lock.unlock()
            return
        }
        if alive {
            job.state = .running
        }
        lock.unlock()
        if alive, transport.resume(operationId: job.request.operationId) {
            return
        }
        lock.lock()
        job.state = .paused(alive: false)
        lock.unlock()
        start(job)
    }

    private func cancel(_ job: DownloadJob) {
        lock.lock()
        if case .finished = job.state {
            lock.unlock()
            return
        }
        job.state = .finished
        downloads[ObjectIdentifier(job.taskInfo)] = nil
        lock.unlock()
        transport.cancel(operationId: job.request.operationId)
        job.task?.cancel()
        report(job.taskInfo, .failure(URLError(.cancelled)))
    }

    // MARK: Reporting

    private func isTerminal(_ taskInfo: SCTDataSessionTaskInfo) -> Bool {
        switch taskInfo.event {
        case .failure, .successURI, .successURL:
            return true
        default:
            return false
        }
    }

    /// Reports the end of a transfer once: a task already ended elsewhere (failed on network
    /// loss) is left alone.
    private func report(_ taskInfo: SCTDataSessionTaskInfo, _ event: SCTDataSessionTaskInfo.Event) {
        guard !isTerminal(taskInfo) else { return }
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
    /// Bumped by every new attempt, so a callback of an earlier one is ignored.
    var attempt = 0
    var task: Task<Void, Never>?

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
    var attempt = 0
    var task: Task<Void, Never>?

    init(request: FileDownloadRequest, taskInfo: SCTDataSessionTaskInfo) {
        self.request = request
        self.taskInfo = taskInfo
    }
}
