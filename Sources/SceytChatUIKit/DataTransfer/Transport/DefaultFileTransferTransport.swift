//
//  DefaultFileTransferTransport.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// The Chat SDK's own transfers: one upload request to the Sceyt file endpoint (encrypted as it
/// is sent, with `ChatClient.uploadEncrypted`), and a plain download of the attachment's URL.
/// The chat server has no multipart upload, so a failed upload starts over as a whole and
/// nothing is saved between attempts.
/// Safe to share: the live transfers are behind `lock`; the hooks and the encryption are set
/// before the first transfer and only read after.
open class DefaultFileTransferTransport: FileTransferTransport, @unchecked Sendable {

    public let encryption: FileEncryption

    private let lock = NSLock()
    private var uploads = [String: LiveTransfer<FileUploadResult>]()
    private var downloads = [String: LiveTransfer<URL>]()

    /// Starts a download request. A test seam: `Session.download` in production.
    var startDownload: (URL, @escaping (Progress) -> Void, @escaping (Result<URL, Error>) -> Void) -> Cancellable? = { url, progress, completion in
        Session.download(url: url, progressHandler: progress, completion: completion)
    }

    /// Where a finished download is moved out of the session's temp location.
    var downloadStagingDirectory: () -> URL = { FileManager.default.temporaryDirectory }

    /// The client uploads go through: the app's, read at each use.
    var chatClient: () -> ChatClient = { SceytChatUIKit.shared.chatClient }

    public init(encryption: FileEncryption = SceytChatUIKit.Components.fileEncryption) {
        self.encryption = encryption
    }

    // MARK: Upload

    open func upload(
        _ request: FileUploadRequest,
        progress: @escaping (Double) -> Void
    ) async -> FileTransferResult<FileUploadResult> {
        let context = TransferLogContext(request)
        let tag = context.tag
        let live = LiveTransfer<FileUploadResult>(operationId: request.operationId, progress: progress)
        guard register(live, operationId: request.operationId, in: \.uploads, tag: tag) else {
            return .failure(FileTransferError.duplicateOperation)
        }
        defer { unregister(live, operationId: request.operationId, in: \.uploads) }
        logger.debug("[Transfer] \(tag) transport upload start type=\(request.type) size=\(TransferLog.sizeText(request.sourceFile))")
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                live.begin(continuation)
                switch request.type {
                case .plain:
                    self.uploadPlain(request, live: live, tag: tag)
                case .encrypted:
                    Task { await TransferLog.$current.withValue(context) { await self.uploadEncrypted(request, live: live, tag: tag) } }
                }
            }
        } onCancel: {
            logger.debug("[Transfer] \(tag) transport upload task cancelled: interrupting the invocation")
            live.end(.interrupted(CancellationError()))
        }
        Self.log(result, "upload", tag: tag)
        return result
    }

    /// Sent as it is. Cannot be stopped: after an interruption its bytes keep going out and its
    /// result is dropped.
    private func uploadPlain(_ request: FileUploadRequest, live: LiveTransfer<FileUploadResult>, tag: String) {
        chatClient().upload(fileUrl: request.sourceFile) { pct in
            live.report(progress: pct)
        } completion: { url, error in
            if let url, error == nil {
                live.finish(.success(FileUploadResult(remoteReference: url.absoluteString)))
                return
            }
            if error == nil {
                logger.warn("[Transfer] \(tag) transport upload: SDK returned neither a url nor an error")
            }
            live.finish(.failure(error ?? FileTransferError.invalidRequest))
        }
    }

    private func uploadEncrypted(_ request: FileUploadRequest, live: LiveTransfer<FileUploadResult>, tag: String) async {
        let session: FileEncryptionSession
        do {
            session = try await encryption.prepareEncryption(file: request.sourceFile)
        } catch {
            logger.debug("[Encryption] \(tag) upload prepare failed: \(TransferLog.describe(error))")
            live.finish(.failure(error))
            return
        }
        let checkpoint = session.checkpoint()
        let context = TransferLog.current
        // Not restorable: a retry sends again under a new key, so nothing is kept. Released
        // once, by whichever ending comes first: the SDK's completion, or a cancel or
        // interruption of the invocation (after which the SDK may never call back).
        let releaseOnce = OnceFlag()
        let release = { [encryption] in
            guard releaseOnce.claim() else { return }
            TransferLog.with(context) {
                session.close()
                encryption.discard(checkpoint)
            }
        }
        // Ended (cancelled or interrupted) while the session was being prepared: nothing is
        // sent. `setStopper` runs the release at once when the invocation is already over.
        live.setStopper(release)
        guard !live.hasEnded else {
            logger.debug("[Encryption] \(tag) upload ended during prepare: the session is released, nothing is sent")
            return
        }
        // `uploadEncrypted` raises for a session another provider prepared.
        guard let sdkSession = session as? ChatSDKEncryptionSession, sdkSession.isSDKStreaming else {
            logger.debug("[Encryption] \(tag) upload rejected (fail closed): session \(type(of: session)) was not prepared by the SDK's streaming provider: it cannot go through ChatClient.uploadEncrypted")
            release()
            live.finish(.failure(AttachmentEncryptionError.encryptionUnsupportedBySession))
            return
        }
        let info = session.encryptionInfo
        // Sizes and the bound id only: never the key.
        logger.info("[Encryption] \(tag) upload encrypt start plaintext=\(session.plaintextSize) B ciphertext=\(session.ciphertextSize) B attachmentId=\(info.attachmentId) alg=\(info.algorithm)")
        let operation = chatClient().uploadEncrypted(sdkSession.upload) { pct in
            live.report(progress: pct)
        } completion: { url, _, error in
            // The session stays open until here, as the SDK requires.
            release()
            if let url, error == nil {
                logger.debug("[Encryption] \(tag) upload encrypt finished, stored ciphertext=\(session.ciphertextSize) B attachmentId=\(info.attachmentId)")
                live.finish(.success(FileUploadResult(remoteReference: url.absoluteString, encryptionInfo: info, plaintextSize: session.plaintextSize)))
            } else {
                if error == nil {
                    logger.warn("[Transfer] \(tag) transport upload: SDK returned neither a url nor an error")
                }
                live.finish(.failure(error ?? FileTransferError.invalidRequest))
            }
        }
        live.setStopper {
            operation.cancel()
            release()
        }
    }

    // MARK: Download

    open func download(
        _ request: FileDownloadRequest,
        progress: @escaping (Double) -> Void
    ) async -> FileTransferResult<URL> {
        let context = TransferLogContext(request)
        let tag = context.tag
        guard let url = URL(string: request.url) else {
            logger.debug("[Transfer] \(tag) transport download url does not parse (\(TransferLog.redact(request.url))): invalidRequest")
            return .failure(FileTransferError.invalidRequest)
        }
        let live = LiveTransfer<URL>(operationId: request.operationId, progress: progress)
        guard register(live, operationId: request.operationId, in: \.downloads, tag: tag) else {
            return .failure(FileTransferError.duplicateOperation)
        }
        defer { unregister(live, operationId: request.operationId, in: \.downloads) }
        logger.debug("[Transfer] \(tag) transport download start url=\(TransferLog.redact(url)) encrypted=\(request.encryptionInfo != nil)")
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                live.begin(continuation)
                let task = self.startDownload(url, { fraction in
                    live.report(progress: fraction.fractionCompleted)
                }) { result in
                    self.downloadFinished(result, request: request, live: live, tag: tag)
                }
                Self.bindControls(of: task, to: live, tag: tag)
            }
        } onCancel: {
            logger.debug("[Transfer] \(tag) transport download task cancelled: interrupting the invocation")
            live.end(.interrupted(CancellationError()))
        }
        Self.log(result, "download", tag: tag)
        return result
    }

    /// The fetch is over. The task's temp file dies when this returns, so it is moved first;
    /// verification and decryption then run off the session's queue.
    private func downloadFinished(_ result: Result<URL, Error>, request: FileDownloadRequest, live: LiveTransfer<URL>, tag: String) {
        let file: URL
        switch result {
        case .failure(let error):
            live.finish(.failure(error))
            return
        case .success(let fetched):
            file = fetched
        }
        let staging = downloadStagingDirectory().appendingPathComponent("download-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: file, to: staging)
        } catch {
            logger.debug("[Transfer] \(tag) transport download could not move the downloaded file out of the session's temp location: \(TransferLog.describe(error))")
            live.finish(.failure(error))
            return
        }
        logger.debug("[Transfer] \(tag) transport download bytes received (\(TransferLog.sizeText(staging))), publishing")
        let encryption = self.encryption
        Task {
            do {
                try await Self.publish(staging, to: request, encryption: encryption)
                live.finish(.success(request.destinationFile))
            } catch {
                // `publish` logged why.
                live.finish(.failure(error))
            }
        }
    }

    /// `suspend()` rather than `cancel(byProducingResumeData:)`: it keeps the bytes already
    /// received and leaves the task alive for `resume`.
    private static func bindControls(of task: Cancellable?, to live: LiveTransfer<URL>, tag: String) {
        guard let task = task as? URLSessionTask else {
            logger.warn("[Transfer] \(tag) transport download has no URLSessionTask: it cannot be stopped, paused or resumed")
            return
        }
        live.setControls(stop: { [weak task] in task?.cancel() },
                         pause: { [weak task] in task?.suspend() },
                         resume: { [weak task] in task?.resume() })
    }

    /// Debug only: the caller reports the outcome (`AttachmentTransfer`, once, at the end).
    private static func log<T: Sendable>(_ result: FileTransferResult<T>, _ what: String, tag: String) {
        switch result {
        case .success:
            logger.debug("[Transfer] \(tag) transport \(what) finished (success)")
        case .failure(let error):
            logger.debug("[Transfer] \(tag) transport \(what) finished (failure): \(TransferLog.describe(error))")
        case .interrupted(let error):
            logger.debug("[Transfer] \(tag) transport \(what) finished (interrupted): \(TransferLog.describe(error))")
        }
    }

    /// Moves a downloaded object to the request's destination: decrypted and verified first
    /// when it is encrypted, so nothing unverified ever appears there.
    static func publish(_ staging: URL, to request: FileDownloadRequest, encryption: FileEncryption) async throws {
        let context = TransferLogContext(request)
        try await TransferLog.$current.withValue(context) {
            try await publish(staging, to: request, encryption: encryption, tag: context.tag)
        }
    }

    private static func publish(_ staging: URL, to request: FileDownloadRequest, encryption: FileEncryption, tag: String) async throws {
        let fileManager = FileManager.default
        let destination = request.destinationFile
        // Failures are debug: the caller reports the outcome once, at the end.
        do {
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            logger.debug("[Transfer] \(tag) download cannot create the destination folder: \(TransferLog.describe(error))")
            TransferLog.remove(staging, what: "the downloaded file", context: "[Transfer] \(tag) download")
            throw error
        }
        guard let info = request.encryptionInfo else {
            do {
                try replace(destination, with: staging)
            } catch {
                logger.debug("[Transfer] \(tag) download cannot move the file to its destination: \(TransferLog.describe(error))")
                TransferLog.remove(staging, what: "the downloaded file", context: "[Transfer] \(tag) download")
                throw error
            }
            return
        }
        defer { TransferLog.remove(staging, what: "the downloaded ciphertext", context: "[Transfer] \(tag) download") }
        TransferDirectories.removeStaleDecryptionFiles(for: destination, tag: tag)
        let decrypted = TransferDirectories.decryptionFile(for: destination)
        do {
            try await encryption.decrypt(file: staging, to: decrypted, encryptionInfo: info, plaintextSize: request.plaintextSize)
            try replace(destination, with: decrypted)
        } catch {
            logger.debug("[Encryption] \(tag) download decrypt/publish failed, nothing published: \(TransferLog.describe(error))")
            TransferLog.remove(decrypted, what: "the partial plaintext", context: "[Encryption] \(tag) download", level: .error)
            throw error
        }
    }

    static func replace(_ destination: URL, with file: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            logger.debug("[Transfer] \(TransferLog.currentTag) destination \(destination.lastPathComponent) already exists, replacing it")
            _ = try fileManager.replaceItemAt(destination, withItemAt: file)
        } else {
            try fileManager.moveItem(at: file, to: destination)
        }
    }

    // MARK: Control

    /// A paused upload keeps sending (`ChatClient.upload` cannot stop) but holds its result,
    /// so a pause still keeps the message from being sent; a download is suspended.
    open func pause(operationId: String) -> Bool {
        guard let live = live(operationId) else {
            logger.debug("[Transfer] xfer=\(TransferLog.operation(operationId)) transport pause: no live invocation")
            return false
        }
        let paused = live.pause()
        logger.debug("[Transfer] xfer=\(TransferLog.operation(operationId)) transport pause -> \(paused ? "paused, invocation kept" : "already over")")
        return paused
    }

    open func resume(operationId: String) -> Bool {
        guard let live = live(operationId) else {
            logger.debug("[Transfer] xfer=\(TransferLog.operation(operationId)) transport resume: no live invocation")
            return false
        }
        let resumed = live.resume()
        logger.debug("[Transfer] xfer=\(TransferLog.operation(operationId)) transport resume -> \(resumed ? "resumed" : "already over")")
        return resumed
    }

    open func cancel(operationId: String) {
        lock.lock()
        let upload = uploads[operationId]
        let download = downloads[operationId]
        lock.unlock()
        logger.debug("[Transfer] xfer=\(TransferLog.operation(operationId)) transport cancel live upload=\(upload != nil) download=\(download != nil)")
        upload?.end(.failure(FileTransferError.cancelled))
        download?.end(.failure(FileTransferError.cancelled))
    }

    private func live(_ operationId: String) -> LiveControl? {
        lock.lock(); defer { lock.unlock() }
        return uploads[operationId] ?? downloads[operationId]
    }

    /// Registers `live` as the invocation of `operationId`. False, and nothing registered,
    /// while an earlier invocation of it is still running: two invocations would share one
    /// record, and pause / resume / cancel could reach only one of them. One that already
    /// ended (stopped, waiting for its task to unwind) is replaced.
    private func register<T: Sendable>(_ live: LiveTransfer<T>, operationId: String, in table: ReferenceWritableKeyPath<DefaultFileTransferTransport, [String: LiveTransfer<T>]>, tag: String) -> Bool {
        lock.lock()
        if let existing = self[keyPath: table][operationId], !existing.hasEnded {
            lock.unlock()
            logger.warn("[Transfer] \(tag) transport invocation rejected: an invocation of the same operation is still running (duplicateOperation)")
            return false
        }
        self[keyPath: table][operationId] = live
        lock.unlock()
        return true
    }

    private func unregister<T: Sendable>(_ live: LiveTransfer<T>, operationId: String, in table: ReferenceWritableKeyPath<DefaultFileTransferTransport, [String: LiveTransfer<T>]>) {
        lock.lock()
        if self[keyPath: table][operationId] === live {
            self[keyPath: table][operationId] = nil
        }
        lock.unlock()
    }
}

/// True for the first `claim` only, from any thread.
final class OnceFlag {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}

private protocol LiveControl: AnyObject {
    func pause() -> Bool
    func resume() -> Bool
}

/// One running request: its continuation, resumed exactly once, and what pausing it means.
/// Its state is behind `lock`.
private final class LiveTransfer<Success: Sendable>: LiveControl, @unchecked Sendable {
    /// For logs; already redacted.
    let operationId: String
    private let lock = NSLock()
    private var continuation: CheckedContinuation<FileTransferResult<Success>, Never>?
    /// Ended before `begin` handed over the continuation.
    private var early: FileTransferResult<Success>?
    /// Arrived while paused: delivered on resume.
    private var held: FileTransferResult<Success>?
    private var isPaused = false
    private var isOver = false
    private let progress: (Double) -> Void
    private var stopRequest: (() -> Void)?
    private var pauseRequest: (() -> Void)?
    private var resumeRequest: (() -> Void)?

    init(operationId: String, progress: @escaping (Double) -> Void) {
        self.operationId = TransferLog.operation(operationId)
        self.progress = progress
    }

    /// Ended: its result is decided, whatever its request still does.
    var hasEnded: Bool {
        lock.lock(); defer { lock.unlock() }
        return isOver
    }

    func begin(_ continuation: CheckedContinuation<FileTransferResult<Success>, Never>) {
        lock.lock()
        if let early {
            lock.unlock()
            continuation.resume(returning: early)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func setStopper(_ stop: @escaping () -> Void) {
        setControls(stop: stop, pause: nil, resume: nil)
    }

    func setControls(stop: @escaping () -> Void, pause: (() -> Void)?, resume: (() -> Void)?) {
        lock.lock()
        let over = isOver
        if !over {
            stopRequest = stop
            pauseRequest = pause
            resumeRequest = resume
        }
        lock.unlock()
        if over { stop() }
    }

    func report(progress value: Double) {
        lock.lock()
        let muted = isPaused || isOver
        lock.unlock()
        if !muted { progress(value) }
    }

    /// The request's own result.
    func finish(_ result: FileTransferResult<Success>) {
        lock.lock()
        if isPaused, !isOver, held == nil {
            held = result
            lock.unlock()
            logger.info("[Transfer] xfer=\(operationId) transport result arrived while paused: held until resume")
            return
        }
        lock.unlock()
        end(result, stop: false)
    }

    /// Ends the invocation now (cancelled or interrupted), stopping the request.
    func end(_ result: FileTransferResult<Success>) {
        end(result, stop: true)
    }

    private func end(_ result: FileTransferResult<Success>, stop: Bool) {
        lock.lock()
        guard !isOver else {
            lock.unlock()
            return
        }
        isOver = true
        let continuation = continuation
        self.continuation = nil
        if continuation == nil {
            early = result
        }
        let stopRequest = stop ? stopRequest : nil
        self.stopRequest = nil
        lock.unlock()
        stopRequest?()
        continuation?.resume(returning: result)
    }

    func pause() -> Bool {
        lock.lock()
        guard !isOver else {
            lock.unlock()
            return false
        }
        isPaused = true
        let pause = pauseRequest
        lock.unlock()
        pause?()
        return true
    }

    func resume() -> Bool {
        lock.lock()
        guard !isOver else {
            lock.unlock()
            return false
        }
        isPaused = false
        let held = held
        self.held = nil
        let resume = resumeRequest
        lock.unlock()
        if let held {
            end(held, stop: false)
        } else {
            resume?()
        }
        return true
    }
}
