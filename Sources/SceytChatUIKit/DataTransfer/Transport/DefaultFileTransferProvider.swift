//
//  DefaultFileTransferProvider.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// The Chat SDK's own transfers: one upload request to the Sceyt file endpoint, and a plain
/// download of the attachment's URL. It prepares nothing (`prepareUpload` returns nil) and
/// encrypts nothing. The chat server has no multipart upload, so a failed upload starts over
/// as a whole and nothing is saved between attempts.
/// Safe to share: the live transfers are behind `lock`; the hooks are set before the first
/// transfer and only read after.
open class DefaultFileTransferProvider: FileTransferProvider, @unchecked Sendable {

    private let lock = NSLock()
    private var uploads = [String: LiveTransfer<FileUploadResult>]()
    private var downloads = [String: LiveTransfer<URL>]()
    /// The resume data keeper of each running download, so a cancel can drop what it saved.
    private var resumes = [String: DownloadResume]()

    /// Where interrupted downloads keep their resume data: Caches, not next to the attachments
    /// (it holds the request, headers included). A test seam.
    nonisolated(unsafe) static var resumeDirectory: URL = TransferDirectories.cachesOrTemporary()
        .appendingPathComponent("download-resume", isDirectory: true)

    /// How long resume data nobody continued is kept.
    static let staleResumeAge: TimeInterval = 7 * 24 * 60 * 60

    /// Where an interrupted download of `operationId` keeps its resume data.
    public static func resumeDataFile(operationId: String) -> URL {
        resumeDirectory.appendingPathComponent(TransferLog.hash([operationId]) + ".resume")
    }

    /// Removes resume data not touched for `staleResumeAge`: its download was never continued
    /// (the message was deleted, or the attachment abandoned before a relaunch).
    static func purgeStaleResumeData(now: Date = Date()) {
        let files = (try? FileManager.default.contentsOfDirectory(at: resumeDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files where file.pathExtension == "resume" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            guard now.timeIntervalSince(modified) > staleResumeAge else { continue }
            TransferLog.remove(file, what: "stale resume data", context: "[Transfer] resume purge")
        }
    }

    /// Starts a download request. A test seam: `Session.download` in production.
    var startDownload: (URLRequest, @escaping (Progress) -> Void, @escaping (Result<URL, Error>) -> Void) -> Cancellable? = { request, progress, completion in
        Session.download(request: request, progressHandler: progress, completion: completion)
    }

    /// Continues a download from the resume data an interrupted one saved. A test seam.
    var startResumedDownload: (Data, @escaping (Progress) -> Void, @escaping (Result<URL, Error>) -> Void) -> Cancellable? = { data, progress, completion in
        Session.download(resumeData: data, progressHandler: progress, completion: completion)
    }

    /// Where a finished download is moved out of the session's temp location.
    var downloadStagingDirectory: () -> URL = { FileManager.default.temporaryDirectory }

    /// The client uploads go through: the app's, read at each use.
    var chatClient: () -> ChatClient = { SceytChatUIKit.shared.chatClient }

    public init() {
        DispatchQueue.global(qos: .utility).async { Self.purgeStaleResumeData() }
    }

    // MARK: Upload

    open func upload(
        _ request: FileUploadRequest,
        progress: @escaping (Double) -> Void
    ) async -> FileTransferResult<FileUploadResult> {
        let tag = TransferLogContext(request).tag
        let live = LiveTransfer<FileUploadResult>(operationId: request.operationId, progress: progress)
        guard register(live, operationId: request.operationId, in: \.uploads, tag: tag) else {
            return .failure(FileTransferError.duplicateOperation)
        }
        defer { unregister(live, operationId: request.operationId, in: \.uploads) }
        logger.debug("[Transfer] \(tag) transport upload start size=\(TransferLog.sizeText(request.sourceFile))")
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                live.begin(continuation)
                self.uploadPlain(request, live: live, tag: tag)
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
                live.finish(.success(FileUploadResult(url: url.absoluteString)))
                return
            }
            if error == nil {
                logger.warn("[Transfer] \(tag) transport upload: SDK returned neither a url nor an error")
            }
            live.finish(.failure(error ?? FileTransferError.invalidRequest))
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
        var urlRequest = URLRequest(url: url)
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        // Kept registered after this invocation: a stop's resume data lands after it returned,
        // and a later cancel must still be able to drop it.
        let resume = register(DownloadResume(file: Self.resumeDataFile(operationId: request.operationId), tag: tag), operationId: request.operationId)
        let saved = resume.take()
        logger.debug("[Transfer] \(tag) transport download start url=\(TransferLog.redact(url)) headers=\(request.headers.count) resumed=\(saved != nil)")
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                live.begin(continuation)
                let progress: (Progress) -> Void = { fraction in
                    live.report(progress: fraction.fractionCompleted)
                }
                // Refers to itself (a refused resume starts again with it), so it lets go of
                // itself as it runs: no request outstanding, no cycle left.
                var completion: ((Result<URL, Error>) -> Void)?
                var resumed = saved != nil
                completion = { result in
                    let current = completion
                    completion = nil
                    if case .failure(let error) = result {
                        if resumed, let current, !Self.isNetworkLoss(error), !Self.isCancellation(error), !live.hasEnded {
                            // The saved request no longer works (expired url, refreshed headers,
                            // a changed object): fetched again from the start, as asked now.
                            // Not after a stop or a cancel: that is no refusal.
                            resumed = false
                            completion = current
                            logger.debug("[Transfer] \(tag) transport download resume refused (\(TransferLog.describe(error))): starting over")
                            let task = self.startDownload(urlRequest, progress, current)
                            Self.bindControls(of: task, to: live, resume: resume, tag: tag)
                            return
                        }
                        // A network failure leaves what arrived, to continue from next time.
                        resume.save((error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data)
                    } else {
                        resume.finished()
                        self.forgetResume(resume, operationId: request.operationId)
                    }
                    self.downloadFinished(result, request: request, live: live, tag: tag)
                }
                let start = completion!
                let task = saved.map { self.startResumedDownload($0, progress, start) }
                    ?? self.startDownload(urlRequest, progress, start)
                Self.bindControls(of: task, to: live, resume: resume, tag: tag)
            }
        } onCancel: {
            logger.debug("[Transfer] \(tag) transport download task cancelled: interrupting the invocation")
            live.end(.interrupted(CancellationError()))
        }
        Self.log(result, "download", tag: tag)
        return result
    }

    /// The fetch is over. The task's temp file dies when this returns, so it is moved first.
    private func downloadFinished(_ result: Result<URL, Error>, request: FileDownloadRequest, live: LiveTransfer<URL>, tag: String) {
        let file: URL
        switch result {
        case .failure(let error):
            // A lost network leaves what arrived (resume data): an interruption, not a failure,
            // so nothing kept for the next attempt is discarded.
            live.finish(Self.isNetworkLoss(error) ? .interrupted(error) : .failure(error))
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
        do {
            try Self.publish(staging, to: request)
            live.finish(.success(request.destinationFile))
        } catch {
            // `publish` logged why.
            live.finish(.failure(error))
        }
    }

    /// A pause is `suspend()`: it keeps the bytes already received and leaves the task alive
    /// for `resume`. A stop keeps them as resume data, for the next attempt (a cancel drops it).
    private static func bindControls(of task: Cancellable?, to live: LiveTransfer<URL>, resume: DownloadResume, tag: String) {
        guard let task = task as? URLSessionTask else {
            logger.warn("[Transfer] \(tag) transport download has no URLSessionTask: it cannot be stopped, paused or resumed")
            return
        }
        live.setControls(stop: { [weak task] in
                            if let download = task as? URLSessionDownloadTask {
                                download.cancel { resume.save($0) }
                            } else {
                                task?.cancel()
                            }
                         },
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

    /// Moves the downloaded bytes to the request's destination, as they were stored.
    static func publish(_ staging: URL, to request: FileDownloadRequest) throws {
        let tag = TransferLogContext(request).tag
        let destination = request.destinationFile
        // Failures are debug: the caller reports the outcome once, at the end.
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try replace(destination, with: staging)
        } catch {
            logger.debug("[Transfer] \(tag) download cannot move the file to its destination: \(TransferLog.describe(error))")
            TransferLog.remove(staging, what: "the downloaded file", context: "[Transfer] \(tag) download")
            throw error
        }
    }

    /// Moves `file` to `destination`, replacing what is there. The one move every transfer
    /// publishes through.
    static func replace(_ destination: URL, with file: URL) throws {
        let fileManager = FileManager.default
        guard file.standardizedFileURL != destination.standardizedFileURL else { return }
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

    /// The resume keeper of `operationId`: the one an earlier invocation left (its resume data
    /// may still be landing), or `new`.
    private func register(_ new: DownloadResume, operationId: String) -> DownloadResume {
        lock.lock(); defer { lock.unlock() }
        if let kept = resumes[operationId], kept.file == new.file { return kept }
        resumes[operationId] = new
        return new
    }

    private func forgetResume(_ resume: DownloadResume, operationId: String) {
        lock.lock(); defer { lock.unlock() }
        if resumes[operationId] === resume { resumes[operationId] = nil }
    }

    static func isCancellation(_ error: Error) -> Bool {
        let ns = error as NSError
        return error is CancellationError || (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled)
    }

    /// The connection went away: what arrived can be continued.
    static func isNetworkLoss(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return false }
        return [
            NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed, NSURLErrorCannotFindHost,
            NSURLErrorInternationalRoamingOff, NSURLErrorDataNotAllowed, NSURLErrorCallIsActive,
        ].contains(ns.code)
    }

    open func cancel(operationId: String) {
        lock.lock()
        let upload = uploads[operationId]
        let download = downloads[operationId]
        let resume = resumes[operationId]
        lock.unlock()
        logger.debug("[Transfer] xfer=\(TransferLog.operation(operationId)) transport cancel live upload=\(upload != nil) download=\(download != nil)")
        // Abandoned: no resume data is kept for it, now or by its stop.
        resume?.abandon()
        if let resume { forgetResume(resume, operationId: operationId) }
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
    private func register<T: Sendable>(_ live: LiveTransfer<T>, operationId: String, in table: ReferenceWritableKeyPath<DefaultFileTransferProvider, [String: LiveTransfer<T>]>, tag: String) -> Bool {
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

    private func unregister<T: Sendable>(_ live: LiveTransfer<T>, operationId: String, in table: ReferenceWritableKeyPath<DefaultFileTransferProvider, [String: LiveTransfer<T>]>) {
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

/// The resume data of one download: saved when it is interrupted, taken by the next attempt,
/// dropped when the download is abandoned. Never a partial file at the destination.
final class DownloadResume: @unchecked Sendable {
    let file: URL
    private let tag: String
    private let lock = NSLock()
    private var abandoned = false

    init(file: URL, tag: String) {
        self.file = file
        self.tag = tag
    }

    /// The saved resume data, removed so it is used once.
    func take() -> Data? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: file) else { return nil }
        try? FileManager.default.removeItem(at: file)
        return data
    }

    func save(_ data: Data?) {
        guard let data, !data.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        guard !abandoned else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            logger.debug("[Transfer] \(tag) transport download interrupted: \(data.count) B of resume data kept")
        } catch {
            logger.debug("[Transfer] \(tag) transport download resume data not kept: \(TransferLog.describe(error))")
        }
    }

    func abandon() {
        lock.lock(); defer { lock.unlock() }
        abandoned = true
        TransferLog.remove(file, what: "the resume data", context: "[Transfer] \(tag) transport download")
    }

    /// The download completed: no resume data is kept, nor saved later.
    func finished() {
        abandon()
    }
}
