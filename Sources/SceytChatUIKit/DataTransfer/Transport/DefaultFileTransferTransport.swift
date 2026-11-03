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
open class DefaultFileTransferTransport: FileTransferTransport {

    public let encryption: FileEncryption

    private let lock = NSLock()
    private var uploads = [String: LiveTransfer<FileUploadResult>]()
    private var downloads = [String: LiveTransfer<URL>]()

    public init(encryption: FileEncryption = SceytChatUIKit.Components.fileEncryption) {
        self.encryption = encryption
    }

    // MARK: Upload

    open func upload(
        _ request: FileUploadRequest,
        progress: @escaping (Double) -> Void
    ) async -> FileTransferResult<FileUploadResult> {
        let live = LiveTransfer<FileUploadResult>(progress: progress)
        register(live, operationId: request.operationId, in: \.uploads)
        defer { unregister(live, operationId: request.operationId, in: \.uploads) }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                live.begin(continuation)
                switch request.type {
                case .plain:
                    // Cannot be stopped: after an interruption its bytes keep going out and its
                    // result is dropped.
                    SceytChatUIKit.shared.chatClient.upload(fileUrl: request.sourceFile) { pct in
                        live.report(progress: pct)
                    } completion: { url, error in
                        if let url, error == nil {
                            live.finish(.success(FileUploadResult(remoteReference: url.absoluteString)))
                        } else {
                            live.finish(.failure(error ?? FileTransferError.invalidRequest))
                        }
                    }
                case .encrypted:
                    Task { await self.uploadEncrypted(request, live: live) }
                }
            }
        } onCancel: {
            live.end(.interrupted(CancellationError()))
        }
    }

    private func uploadEncrypted(_ request: FileUploadRequest, live: LiveTransfer<FileUploadResult>) async {
        let session: FileEncryptionSession
        do {
            session = try await encryption.prepare(file: request.sourceFile)
        } catch {
            live.finish(.failure(error))
            return
        }
        let checkpoint = session.checkpoint()
        // Not restorable: a retry sends again under a new key, so nothing is kept.
        let release = { [encryption] in
            session.close()
            encryption.discard(checkpoint)
        }
        // `uploadEncrypted` raises for a session another provider prepared.
        guard let sdkSession = session as? ChatSDKEncryptionSession,
              Components.fileEncryptionProvider is StreamingAeadFileEncryptionProvider
        else {
            release()
            live.finish(.failure(AttachmentEncryptionError.encryptionUnsupportedBySession))
            return
        }
        let info = session.encryptionInfo
        let operation = SceytChatUIKit.shared.chatClient.uploadEncrypted(sdkSession.upload) { pct in
            live.report(progress: pct)
        } completion: { url, _, error in
            // The session stays open until here, as the SDK requires.
            release()
            if let url, error == nil {
                live.finish(.success(FileUploadResult(remoteReference: url.absoluteString, encryptionInfo: info)))
            } else {
                live.finish(.failure(error ?? FileTransferError.invalidRequest))
            }
        }
        live.setStopper { operation.cancel() }
    }

    // MARK: Download

    open func download(
        _ request: FileDownloadRequest,
        progress: @escaping (Double) -> Void
    ) async -> FileTransferResult<URL> {
        guard let url = URL(string: request.url) else {
            return .failure(FileTransferError.invalidRequest)
        }
        let live = LiveTransfer<URL>(progress: progress)
        register(live, operationId: request.operationId, in: \.downloads)
        defer { unregister(live, operationId: request.operationId, in: \.downloads) }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                live.begin(continuation)
                let task = Session.download(url: url) { fraction in
                    live.report(progress: fraction.fractionCompleted)
                } completion: { [encryption] result in
                    switch result {
                    case .failure(let error):
                        live.finish(.failure(error))
                    case .success(let file):
                        // The task's temp file dies when this callback returns, so it is moved
                        // first; verification and decryption then run off the session's queue.
                        let staging = FileManager.default.temporaryDirectory
                            .appendingPathComponent("download-\(UUID().uuidString)")
                        do {
                            try FileManager.default.moveItem(at: file, to: staging)
                        } catch {
                            live.finish(.failure(error))
                            return
                        }
                        Task {
                            do {
                                try await Self.publish(staging, to: request, encryption: encryption)
                                live.finish(.success(request.destinationFile))
                            } catch {
                                live.finish(.failure(error))
                            }
                        }
                    }
                }
                // `suspend()` rather than `cancel(byProducingResumeData:)`: it keeps the bytes
                // already received and leaves the task alive for `resume`.
                if let task = task as? URLSessionTask {
                    live.setControls(stop: { [weak task] in task?.cancel() },
                                     pause: { [weak task] in task?.suspend() },
                                     resume: { [weak task] in task?.resume() })
                }
            }
        } onCancel: {
            live.end(.interrupted(CancellationError()))
        }
    }

    /// Moves a downloaded object to the request's destination: decrypted and verified first
    /// when it is encrypted, so nothing unverified ever appears there.
    static func publish(_ staging: URL, to request: FileDownloadRequest, encryption: FileEncryption) async throws {
        let fileManager = FileManager.default
        let destination = request.destinationFile
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let info = request.encryptionInfo else {
            try replace(destination, with: staging)
            return
        }
        defer { try? fileManager.removeItem(at: staging) }
        let decrypted = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString)-\(destination.lastPathComponent)")
        do {
            try await encryption.decrypt(file: staging, to: decrypted, encryptionInfo: info, plaintextSize: request.plaintextSize)
            try replace(destination, with: decrypted)
        } catch {
            try? fileManager.removeItem(at: decrypted)
            throw error
        }
    }

    static func replace(_ destination: URL, with file: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: file)
        } else {
            try fileManager.moveItem(at: file, to: destination)
        }
    }

    // MARK: Control

    /// A paused upload keeps sending (`ChatClient.upload` cannot stop) but holds its result,
    /// so a pause still keeps the message from being sent; a download is suspended.
    open func pause(operationId: String) -> Bool {
        live(operationId)?.pause() ?? false
    }

    open func resume(operationId: String) -> Bool {
        live(operationId)?.resume() ?? false
    }

    open func cancel(operationId: String) {
        lock.lock()
        let upload = uploads[operationId]
        let download = downloads[operationId]
        lock.unlock()
        upload?.end(.failure(FileTransferError.cancelled))
        download?.end(.failure(FileTransferError.cancelled))
    }

    private func live(_ operationId: String) -> LiveControl? {
        lock.lock(); defer { lock.unlock() }
        return uploads[operationId] ?? downloads[operationId]
    }

    private func register<T>(_ live: LiveTransfer<T>, operationId: String, in table: ReferenceWritableKeyPath<DefaultFileTransferTransport, [String: LiveTransfer<T>]>) {
        lock.lock()
        self[keyPath: table][operationId] = live
        lock.unlock()
    }

    private func unregister<T>(_ live: LiveTransfer<T>, operationId: String, in table: ReferenceWritableKeyPath<DefaultFileTransferTransport, [String: LiveTransfer<T>]>) {
        lock.lock()
        if self[keyPath: table][operationId] === live {
            self[keyPath: table][operationId] = nil
        }
        lock.unlock()
    }
}

private protocol LiveControl: AnyObject {
    func pause() -> Bool
    func resume() -> Bool
}

/// One running request: its continuation, resumed exactly once, and what pausing it means.
private final class LiveTransfer<Success>: LiveControl {
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

    init(progress: @escaping (Double) -> Void) {
        self.progress = progress
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
