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
    static func upload(fileUrl: URL, completion: @escaping (Result<String, Error>) -> Void) {
        SceytChatUIKit.shared.chatClient.upload(fileUrl: fileUrl) { _ in
        } completion: { url, error in
            if let url {
                completion(.success(url.absoluteString))
            } else {
                completion(.failure(error ?? SCTDataSessionError.thumbnailUploadFailed))
            }
        }
    }

    static func download(origin: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: origin),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            completion(.failure(SCTDataSessionError.unsupportedThumbnailOrigin))
            return
        }
        URLSession.shared.downloadTask(with: url) { location, _, error in
            guard let location, error == nil else {
                completion(.failure(error ?? SCTDataSessionError.thumbnailDownloadFailed))
                return
            }
            // The task's temp file dies when this callback returns — move it first.
            let stable = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("video_thumb_\(UUID().uuidString)")
                .appendingPathExtension("jpg")
            do {
                try FileManager.default.moveItem(at: location, to: stable)
                completion(.success(stable))
            } catch {
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
    
    internal init(
        transferType: TransferType,
        message: ChatMessage,
        attachment: ChatMessage.Attachment
    ) {
        self.transferType = transferType
        self.message = message
        self.attachment = attachment
        super.init()
    }
    
    public func updateLocalFileLocation(newLocation: URL) {
        event = .updateLocalFileURL(newLocation, attachment.filePath)
        onEvent?(.updateLocalFileURL(newLocation, attachment.filePath))
        attachment.filePath = newLocation.path
    }
    
    public func updateLocalFileLocation(newPath: String) {
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
        event = .failure(error)
        onEvent?(.failure(error))
    }
    
    public func success(origin uri: String) {
        attachment.url = uri
        event = .successURI(uri)
        onEvent?(.successURI(uri))
    }
    
    public func success(origin url: URL) {
        attachment.url = url.absoluteString
        event = .successURL(url)
        onEvent?(.successURL(url))
    }
    
    deinit {}
    
    public func cancel() {
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
        guard !isTransferFinished else { return }
        attachment.status = transferType == .upload ? .pauseUploading : .pauseDownloading
        action = .stop
        onAction?(.stop)
    }

    public func resume() {
        guard !isTransferFinished else { return }
        attachment.status = transferType == .upload ? .uploading : .downloading
        action = .resume
        onAction?(.resume)
    }
    
    public func startChecksum(_ completion: @escaping ((Bool) -> Void)) {
        checksumProvider.startChecksum(
            message: message,
            attachment: attachment,
            encryption: encryption) { [weak self] in
                guard let self else { return }
                switch $0 {
                case .success(let link):
                    if let link {
                        self.success(origin: link)
                        completion(true)
                    } else {
                        completion(false)
                    }
                case .failure(let error):
                    self.failure(error: error)
                    completion(false)
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
