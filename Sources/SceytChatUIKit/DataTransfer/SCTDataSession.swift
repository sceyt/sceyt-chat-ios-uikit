//
//  SCTDataSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import Foundation
import SceytChat

public protocol SCTDataSession: NSObject {
    func upload(
        attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo
    )

    func download(
        attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo
    )

    func getFilePath(attachment: ChatMessage.Attachment) -> String?

    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String?

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

    /// Whether this session encrypts the uploads and decrypts the downloads of encrypted tasks
    /// (`TransportDataSession` does, through its transport). When it does not, an attachment
    /// that requires encryption fails instead of going out as plaintext.
    var supportsAttachmentEncryption: Bool { get }
}

public enum SCTDataSessionError: Error {
    case thumbnailUploadFailed
    case thumbnailDownloadFailed
    case unsupportedThumbnailOrigin
}

public extension SCTDataSession {
    var supportsAttachmentEncryption: Bool { false }

    func uploadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        fileUrl: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        DefaultThumbnailTransfer.upload(fileUrl: fileUrl, completion: completion)
    }

    func downloadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        origin: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DefaultThumbnailTransfer.download(origin: origin, completion: completion)
    }
}

/// Video posters through the Chat SDK's upload and a plain download of their URL.
enum DefaultThumbnailTransfer {
    /// Where a downloaded poster is moved out of the session's temp location. A test seam.
    static var posterDirectory: () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }

    static func upload(fileUrl: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let tag = TransferLog.currentTag
        logger.debug("[Transfer] \(tag) poster upload start size=\(TransferLog.sizeText(fileUrl))")
        SceytChatUIKit.shared.chatClient.upload(fileUrl: fileUrl) { _ in
        } completion: { url, error in
            if let url {
                logger.debug("[Transfer] \(tag) poster upload finished ref=\(TransferLog.redact(url))")
                completion(.success(url.absoluteString))
            } else {
                logger.debug("[Transfer] \(tag) poster upload failed: \(TransferLog.describe(error ?? SCTDataSessionError.thumbnailUploadFailed))")
                completion(.failure(error ?? SCTDataSessionError.thumbnailUploadFailed))
            }
        }
    }

    static func download(origin: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: origin),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            logger.warn("[Transfer] poster download rejected: unsupported origin \(TransferLog.redact(origin))")
            completion(.failure(SCTDataSessionError.unsupportedThumbnailOrigin))
            return
        }
        URLSession.shared.downloadTask(with: url) { location, response, error in
            guard let location, error == nil else {
                logger.warn("[Transfer] poster download \(TransferLog.redact(url)) failed: \(TransferLog.describe(error ?? SCTDataSessionError.thumbnailDownloadFailed))")
                completion(.failure(error ?? SCTDataSessionError.thumbnailDownloadFailed))
                return
            }
            if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
                // Not handled: the error body is kept as the poster (and fails to decode later).
                logger.warn("[Transfer] poster download \(TransferLog.redact(url)) answered HTTP \(status); the body is used as the poster")
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
        }.resume()
    }
}

open class SCTDataSessionTaskInfo: NSObject {
    @Published public private(set) var event: Event?
    @Published public private(set) var action: Action?
    
    public var onAction: ((Action) -> Void)?
    public var onEvent: ((Event) -> Void)?
    public var userInfo: [AnyHashable: Any]?
    private let checksumProvider = Components.channelMessageChecksumProvider.init()

    public enum TransferType {
        case upload
        case download
    }
    
    public let transferType: TransferType
    
    internal let message: ChatMessage
    internal var attachment: ChatMessage.Attachment

    /// `.required` when this transfer must be encrypted: set before the session sees the
    /// task, from the key provider (upload) or the attachment's metadata (download).
    public internal(set) var encryption: EncryptionRequirement = .none
    /// The received attachment's `enc`, read before the download started.
    internal var downloadEncryption: AttachmentEncryption?
    /// The encryption of the uploaded object, from the transport's `FileUploadResult`.
    internal var uploadedEncryption: EncryptedFileInfo?
    /// The size of the prepared file an encrypted upload sent: the message shows it, not the
    /// stored object's.
    internal var uploadedPlaintextSize: Int64?
    /// The encrypted video poster sent with this upload, for `enc.renditions`.
    internal var thumbnailRendition: AttachmentEncryption.Rendition?
    /// The transport returned the verified plaintext of an encrypted download.
    internal var didDecryptDownload = false

    /// Names this transfer in every log line of every layer (`xfer=`). The data session's own
    /// operation id when it has one (`TransportDataSession`), assigned before the session sees
    /// the task.
    public var operationId: String {
        stateLock.lock(); defer { stateLock.unlock() }
        return assignedOperationId ?? fallbackOperationId
    }
    /// When the task was made: a transfer's duration is measured from here.
    internal let startedAt = Date()
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
        attachment: ChatMessage.Attachment
    ) {
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
        switch event {
        case .failure, .successURI, .successURL:
            return true
        default:
            return false
        }
    }
    
    public func updateLocalFileLocation(newLocation: URL) {
        logEventDiagnostics("updateLocalFileURL")
        event = .updateLocalFileURL(newLocation, attachment.filePath)
        onEvent?(.updateLocalFileURL(newLocation, attachment.filePath))
        attachment.filePath = newLocation.path
    }
    
    public func updateLocalFileLocation(newPath: String) {
        logEventDiagnostics("updateLocalFileURL")
        event = .updateLocalFileURL(URL(fileURLWithPath: newPath), attachment.filePath)
        onEvent?(.updateLocalFileURL(URL(fileURLWithPath: newPath), attachment.filePath))
        attachment.filePath = newPath
    }
    
    public func updateProgress(_ progress: Double) {
        attachment.transferProgress = progress
        event = .updateProgress(progress)
        onEvent?(.updateProgress(progress))
    }
    
    public func failure(error: Error?) {
        logEventDiagnostics("failure(\(TransferLog.describe(error)))")
        event = .failure(error)
        onEvent?(.failure(error))
    }

    /// `AttachmentTransfer` turning a success its gate refused into a failure: expected after
    /// a terminal event, so not reported as one arriving late.
    func reject(error: Error) {
        event = .failure(error)
        onEvent?(.failure(error))
    }
    
    public func success(origin uri: String) {
        logEventDiagnostics("successURI(\(TransferLog.redact(uri)))")
        attachment.url = uri
        event = .successURI(uri)
        onEvent?(.successURI(uri))
    }
    
    public func success(origin url: URL) {
        logEventDiagnostics("successURL(\(TransferLog.redact(url)))")
        attachment.url = url.absoluteString
        event = .successURL(url)
        onEvent?(.successURL(url))
    }
    
    deinit {}

    /// An event emitted before `AttachmentTransfer` installed `onEvent` (lost), or after a
    /// terminal one (it replaces it). Neither should happen; both are logged if they do.
    private func logEventDiagnostics(_ name: @autoclosure () -> String) {
        let ended: String?
        switch event {
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
        // The provider tags its own lines from the bound context.
        TransferLog.with(logContext) {
            checksumProvider.startChecksum(
                message: message,
                attachment: attachment,
                encryption: encryption) { [weak self] in
                    guard let self else { return }
                    switch $0 {
                    case .success(let link):
                        if let link {
                            logger.info("[Transfer] \(self.logTag) upload checksum hit: reusing \(TransferLog.redact(link)) encryption=\(self.encryption) \(self.attachment.transferLogDescription)")
                            self.success(origin: link)
                            completion(true)
                        } else {
                            logger.debug("[Transfer] \(self.logTag) upload checksum miss")
                            completion(false)
                        }
                    case .failure(let error):
                        // Reported at the end, once, by `AttachmentTransfer`.
                        logger.debug("[Transfer] \(self.logTag) upload checksum step failed, the upload fails: \(TransferLog.describe(error))")
                        self.failure(error: error)
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
