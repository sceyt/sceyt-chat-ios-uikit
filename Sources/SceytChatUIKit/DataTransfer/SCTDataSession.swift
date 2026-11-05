//
//  SCTDataSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// Everything `AttachmentTransfer` asks of a data session: its transfers, its local files and
/// its poster transfers. Code that needs one of them depends on that protocol alone.
public protocol SCTDataSession: AttachmentTransferring, AttachmentLocalFiles, AttachmentThumbnailTransferring {}

/// Sends and fetches attachments. Used from the transfer's queue, the transport's tasks and
/// the caller's thread: a conforming session must be safe to share between them.
public protocol AttachmentTransferring: NSObject, Sendable {
    func upload(
        attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo
    )

    func download(
        attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo
    )

    /// Whether this session encrypts the uploads and decrypts the downloads of encrypted tasks
    /// (`TransportDataSession` does, through its transport). When it does not, an attachment
    /// that requires encryption fails instead of going out as plaintext.
    var supportsAttachmentEncryption: Bool { get }
}

/// Where a session keeps attachments' files and their thumbnails.
public protocol AttachmentLocalFiles: AnyObject, Sendable {
    func getFilePath(attachment: ChatMessage.Attachment) -> String?

    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String?
}

/// Sends and fetches video posters.
public protocol AttachmentThumbnailTransferring: AnyObject, Sendable {

    /// Uploads a poster-frame image for a video attachment. Calls back with the
    /// opaque origin string stored under the `"video_thumb"` metadata key —
    /// whatever this session's `downloadAttachmentThumbnail` can later resolve
    /// (the default session uses a full URL; a host session may use a transfer id).
    func uploadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        fileUrl: URL,
        completion: @escaping (Result<String, Error>) -> Void
    )

    /// Downloads the poster-frame image identified by the opaque `origin`
    /// (the `"video_thumb"` metadata value). Calls back with a local file URL;
    /// a temporary location is fine — the caller moves it into its own cache.
    func downloadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        origin: String,
        completion: @escaping (Result<URL, Error>) -> Void
    )
}

public enum SCTDataSessionError: Error {
    case thumbnailUploadFailed
    case thumbnailDownloadFailed
    case unsupportedThumbnailOrigin
}

public extension AttachmentTransferring {
    var supportsAttachmentEncryption: Bool { false }
}

public extension AttachmentThumbnailTransferring {
    func uploadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        fileUrl: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        DefaultThumbnailTransfer().upload(fileUrl: fileUrl, completion: completion)
    }

    func downloadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        origin: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DefaultThumbnailTransfer().download(origin: origin, completion: completion)
    }
}

/// Video posters through the Chat SDK's upload and a plain download of their URL.
struct DefaultThumbnailTransfer {
    /// Where a downloaded poster is moved out of the session's temp location.
    var posterDirectory: () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }

    /// The client posters are uploaded through: the app's, read at each use.
    var chatClient: () -> ChatClient = { SceytChatUIKit.shared.chatClient }

    /// Starts a poster download: a `URLSession.shared` download task by default.
    var startDownload: (URL, @escaping (URL?, URLResponse?, Error?) -> Void) -> Void = { url, completion in
        // Handed to the session, which calls it once, on its delegate queue.
        let handoff = Handoff(completion)
        URLSession.shared.downloadTask(with: url) { handoff.value($0, $1, $2) }.resume()
    }

    func upload(fileUrl: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let tag = TransferLog.currentTag
        logger.debug("[Transfer] \(tag) poster upload start size=\(TransferLog.sizeText(fileUrl))")
        // Handed to the SDK, which calls it once, on its own queue.
        let handoff = Handoff(completion)
        chatClient().upload(fileUrl: fileUrl) { _ in
        } completion: { url, error in
            let completion = handoff.value
            if let url {
                logger.debug("[Transfer] \(tag) poster upload finished ref=\(TransferLog.redact(url))")
                completion(.success(url.absoluteString))
            } else {
                logger.debug("[Transfer] \(tag) poster upload failed: \(TransferLog.describe(error ?? SCTDataSessionError.thumbnailUploadFailed))")
                completion(.failure(error ?? SCTDataSessionError.thumbnailUploadFailed))
            }
        }
    }

    func download(origin: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: origin),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            logger.warn("[Transfer] poster download rejected: unsupported origin \(TransferLog.redact(origin))")
            completion(.failure(SCTDataSessionError.unsupportedThumbnailOrigin))
            return
        }
        startDownload(url) { location, response, error in
            guard let location, error == nil else {
                logger.warn("[Transfer] poster download \(TransferLog.redact(url)) failed: \(TransferLog.describe(error ?? SCTDataSessionError.thumbnailDownloadFailed))")
                completion(.failure(error ?? SCTDataSessionError.thumbnailDownloadFailed))
                return
            }
            if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
                // An error body cached as the poster would count as downloaded and never be
                // fetched again: the video would keep its blurred placeholder for good.
                logger.warn("[Transfer] poster download \(TransferLog.redact(url)) answered HTTP \(status), failed")
                TransferLog.remove(location, what: "the error body", context: "[Transfer] poster download", level: .debug)
                completion(.failure(SCTDataSessionError.thumbnailDownloadFailed))
                return
            }
            // The task's temp file dies when this callback returns — move it first.
            let stable = posterDirectory()
                .appendingPathComponent("video_thumb_\(UUID().uuidString)")
                .appendingPathExtension("jpg")
            do {
                try FileManager.default.moveItem(at: location, to: stable)
                completion(.success(stable))
            } catch {
                logger.warn("[Transfer] poster download \(TransferLog.redact(url)) could not be moved out of the temp location: \(TransferLog.describe(error))")
                completion(.failure(error))
            }
        }
    }
}

/// Safe to share between threads: `event` and `action` are guarded by the event lock, the
/// attempt state by its own lock, and every other mutable field is `@Atomic`.
open class SCTDataSessionTaskInfo: NSObject, @unchecked Sendable {
    /// The last event: progress, a moved file, or the end (a success or a failure).
    public var event: Event? {
        eventLock.lock(); defer { eventLock.unlock() }
        return _event
    }
    /// The last thing the user asked of this transfer (pause, resume, cancel). Written on
    /// the caller's thread, read by the transfer queues: guarded like `event`.
    public private(set) var action: Action? {
        get { eventLock.lock(); defer { eventLock.unlock() }; return _action }
        set { eventLock.lock(); _action = newValue; eventLock.unlock() }
    }
    private var _action: Action?
    /// Held while an event is recorded and delivered, so events reach `onEvent` one at a time,
    /// in the order they were recorded. Recursive: an `onEvent` handler may emit (reject).
    private let eventLock = NSRecursiveLock()
    private var _event: Event?
    
    @Atomic public var onAction: ((Action) -> Void)?
    @Atomic public var onEvent: ((Event) -> Void)?
    @Atomic public var userInfo: [AnyHashable: Any]?
    private let checksumProvider: ChannelMessageChecksumProvider

    public enum TransferType {
        case upload
        case download
    }
    
    public let transferType: TransferType
    
    internal let message: ChatMessage
    @Atomic internal var attachment: ChatMessage.Attachment

    /// `.required` when this transfer must be encrypted: set before the session sees the
    /// task, from the key provider (upload) or the attachment's metadata (download).
    @Atomic public internal(set) var encryption: EncryptionRequirement = .none
    /// The received attachment's `enc`, read before the download started.
    @Atomic internal var downloadEncryption: AttachmentEncryption?
    /// The encryption of the uploaded object, from the transport's `FileUploadResult`.
    @Atomic internal var uploadedEncryption: EncryptedFileInfo?
    /// The size of the prepared file an encrypted upload sent: the message shows it, not the
    /// stored object's.
    @Atomic internal var uploadedPlaintextSize: Int64?
    /// The size of the file this transfer actually moves, once the data session knows it: an
    /// upload's prepared file (a compressed video can be a small part of its original). Progress
    /// fractions are of these bytes. Nil until reported (`reportTransferSize`).
    @Atomic public private(set) var transferSize: Int64?
    /// Told each reported transfer size (`TransferRun` saves it on the attachment).
    @Atomic internal var onTransferSize: ((Int64) -> Void)?
    /// The encrypted video poster sent with this upload, for `enc.renditions`.
    @Atomic internal var thumbnailRendition: AttachmentEncryption.Rendition?
    /// The transport returned the verified plaintext of an encrypted download.
    @Atomic internal var didDecryptDownload = false

    /// Names this transfer in every log line of every layer (`xfer=`). The data session's own
    /// operation id when it has one (`TransportDataSession`), assigned before the session sees
    /// the task.
    public var operationId: String {
        stateLock.lock(); defer { stateLock.unlock() }
        return assignedOperationId ?? fallbackOperationId
    }
    /// When the task was made: a transfer's duration is measured from here.
    internal let startedAt: Date
    /// Attempts the data session started for this task.
    internal var attempts: Int {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _attempts }
        set { stateLock.lock(); _attempts = newValue; stateLock.unlock() }
    }
    /// The last failure was an interruption (work kept for another attempt), not a refusal.
    internal var wasInterrupted: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _wasInterrupted }
        set { stateLock.lock(); _wasInterrupted = newValue; stateLock.unlock() }
    }
    private let stateLock = NSLock()
    private var assignedOperationId: String?
    private let fallbackOperationId: String
    private var _attempts = 0
    private var _wasInterrupted = false

    internal init(
        transferType: TransferType,
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        startedAt: Date = Date(),
        checksumProvider: ChannelMessageChecksumProvider = Components.channelMessageChecksumProvider.init()
    ) {
        self.startedAt = startedAt
        self.checksumProvider = checksumProvider
        self.transferType = transferType
        self.message = message
        self.attachment = attachment
        switch transferType {
        case .upload:
            fallbackOperationId = attachment.tid != 0 ? "upload-\(attachment.tid)" : "upload-\(UUID().uuidString.prefix(8).lowercased())"
        case .download:
            fallbackOperationId = TransportDataSession.shortDownloadOperationId(for: attachment)
        }
        super.init()
    }

    var hasAssignedOperationId: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return assignedOperationId != nil
    }

    func assign(operationId: String) {
        stateLock.lock(); assignedOperationId = operationId; stateLock.unlock()
    }

    /// Who this task's log lines are about.
    var logContext: TransferLogContext {
        TransferLogContext(operationId: operationId, message: message)
    }

    /// `xfer=<operation> msg=<id>/<tid> channel=<id>`.
    var logTag: String {
        logContext.tag
    }

    /// The task has reported its end (a success or a failure).
    var isTerminal: Bool {
        Self.isEnd(event)
    }

    static func isEnd(_ event: Event?) -> Bool {
        switch event {
        case .failure, .successURI, .successURL:
            return true
        default:
            return false
        }
    }

    /// Records `event` and delivers it to `onEvent`, under the event lock. Progress and a
    /// moved file mean nothing once the task has ended: they are dropped then, so a late tick
    /// can't replace the end (and bring a finished transfer's progress back).
    /// `beforeDelivery` runs under the same lock, before the handler sees the event.
    @discardableResult
    private func emit(_ event: Event, diagnostics: String? = nil, beforeDelivery: () -> Void = {}) -> Bool {
        eventLock.lock(); defer { eventLock.unlock() }
        switch event {
        case .updateProgress, .updateLocalFileURL:
            guard !Self.isEnd(_event) else { return false }
        case .failure, .successURI, .successURL:
            break
        }
        if let diagnostics {
            logEventDiagnostics(diagnostics)
        }
        beforeDelivery()
        _event = event
        onEvent?(event)
        return true
    }

    /// Ends the task with `event` unless it already ended, in one step: a check followed by a
    /// separate report could let two ends race.
    /// - Returns: `false` when the task had already ended (nothing was emitted).
    @discardableResult
    func endIfLive(with event: Event) -> Bool {
        eventLock.lock(); defer { eventLock.unlock() }
        guard !Self.isEnd(_event) else { return false }
        switch event {
        case .failure(let error):
            failure(error: error)
        case .successURI(let uri):
            success(origin: uri)
        case .successURL(let url):
            success(origin: url)
        case .updateProgress, .updateLocalFileURL:
            return false
        }
        return true
    }

    public func updateLocalFileLocation(newLocation: URL) {
        emit(.updateLocalFileURL(newLocation, attachment.filePath), diagnostics: "updateLocalFileURL") {
            attachment.filePath = newLocation.path
        }
    }

    public func updateLocalFileLocation(newPath: String) {
        updateLocalFileLocation(newLocation: URL(fileURLWithPath: newPath))
    }

    /// Reports the size of the file the transfer moves, before its first progress: the
    /// progress shown in bytes is of it, not of the attachment's original. Ignored once the
    /// task has ended.
    public func reportTransferSize(_ size: Int64) {
        guard size > 0, !isTerminal else { return }
        transferSize = size
        onTransferSize?(size)
    }

    public func updateProgress(_ progress: Double) {
        emit(.updateProgress(progress)) {
            attachment.transferProgress = progress
        }
    }

    public func failure(error: Error?) {
        emit(.failure(error), diagnostics: "failure(\(TransferLog.describe(error)))")
    }

    /// `AttachmentTransfer` turning a success its gate refused into a failure: expected after
    /// a terminal event, so not reported as one arriving late.
    func reject(error: Error) {
        emit(.failure(error))
    }

    public func success(origin uri: String) {
        emit(.successURI(uri), diagnostics: "successURI(\(TransferLog.redact(uri)))") {
            attachment.url = uri
        }
    }

    public func success(origin url: URL) {
        emit(.successURL(url), diagnostics: "successURL(\(TransferLog.redact(url)))") {
            attachment.url = url.absoluteString
        }
    }


    /// An event emitted before `AttachmentTransfer` installed `onEvent` (lost), or after a
    /// terminal one (it replaces it). Neither should happen; both are logged if they do.
    private func logEventDiagnostics(_ name: @autoclosure () -> String) {
        let ended: String?
        switch _event {
        case .failure(let error):
            ended = "failure(\(TransferLog.describe(error)))"
        case .successURI, .successURL:
            ended = "success"
        default:
            ended = nil
        }
        if let ended {
            logger.warn("[Transfer] \(logTag) \(transferType) event \(name()) after the task already ended with \(ended) \(attachment.transferLogDescription)")
        }
        if onEvent == nil {
            logger.warn("[Transfer] \(logTag) \(transferType) event \(name()) emitted before the event hooks were installed: it is lost \(attachment.transferLogDescription)")
        }
    }
    
    public func cancel() {
        logger.info("[Transfer] \(logTag) \(transferType) cancel requested (last event \(TransportDataSession.describe(event))) \(attachment.transferLogDescription)")
        attachment.status = .pending
        action = .cancel
        onAction?(.cancel)
    }
    
    /// The transport has delivered the file. `AttachmentTransfer` may still be finishing
    /// (uploading a video's poster frame, persisting), but there is nothing left to pause.
    public var isTransferFinished: Bool {
        switch event {
        case .successURI, .successURL:
            return true
        default:
            return false
        }
    }

    public func stop() {
        // A pause racing the success would overwrite the `.done` just set on this same
        // attachment, leaving a delivered file stuck paused with no task left to resume.
        guard !isTransferFinished else {
            logger.debug("[Transfer] \(logTag) \(transferType) pause ignored: already delivered")
            return
        }
        logger.info("[Transfer] \(logTag) \(transferType) pause requested")
        attachment.status = transferType == .upload ? .pauseUploading : .pauseDownloading
        action = .stop
        onAction?(.stop)
    }

    public func resume() {
        guard !isTransferFinished else {
            logger.debug("[Transfer] \(logTag) \(transferType) resume ignored: already delivered")
            return
        }
        logger.info("[Transfer] \(logTag) \(transferType) resume requested")
        attachment.status = transferType == .upload ? .uploading : .downloading
        action = .resume
        onAction?(.resume)
    }
    
    public func startChecksum(_ completion: @escaping ((Bool) -> Void)) {
        startChecksum(reserve: { true }, completion)
    }

    /// `reserve` is asked first, when the answer comes: false when the waiting upload already
    /// moved on (timed out, paused, cancelled), and the answer then changes nothing. True claims
    /// the wait, so nothing else can end it while the answer is acted on; `completion` then
    /// hands the waiter its value, after the task was ended by it.
    func startChecksum(reserve: @escaping () -> Bool, _ completion: @escaping ((Bool) -> Void)) {
        // The provider tags its own lines from the bound context.
        TransferLog.with(logContext) {
            checksumProvider.startChecksum(
                message: message,
                attachment: attachment,
                encryption: encryption) { [weak self] in
                    guard let self else { return }
                    guard reserve() else {
                        logger.debug("[Transfer] \(self.logTag) upload checksum answered after its wait ended (timed out, paused or cancelled): ignored")
                        return
                    }
                    switch $0 {
                    case .success(let link):
                        if let link {
                            // Only while the task is live: a cancel that already ended it stays
                            // a cancel, and the attachment keeps no url it was never sent with.
                            guard self.endIfLive(with: .successURI(link)) else {
                                logger.debug("[Transfer] \(self.logTag) upload checksum hit after the task ended (\(TransportDataSession.describe(self.event))): ignored")
                                completion(false)
                                return
                            }
                            logger.info("[Transfer] \(self.logTag) upload checksum hit: reusing \(TransferLog.redact(link)) encryption=\(self.encryption) \(self.attachment.transferLogDescription)")
                            completion(true)
                        } else {
                            logger.debug("[Transfer] \(self.logTag) upload checksum miss")
                            completion(false)
                        }
                    case .failure(let error):
                        // Reported at the end, once, by `AttachmentTransfer`.
                        logger.debug("[Transfer] \(self.logTag) upload checksum step failed, the upload fails: \(TransferLog.describe(error))")
                        self.endIfLive(with: .failure(error))
                        completion(false)
                    }
                }
        }
    }
}

public extension SCTDataSessionTaskInfo {
    enum Action {
        case cancel
        case stop
        case resume
    }
    
    enum Event {
        case updateLocalFileURL(URL, String?)
        case updateProgress(Double)
        case failure(Error?)
        case successURI(String)
        case successURL(URL)
    }
}
