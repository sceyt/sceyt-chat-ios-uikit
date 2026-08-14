//
//  SCTDataSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import Foundation

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
}

public enum SCTDataSessionError: Error {
    case thumbnailUploadFailed
    case thumbnailDownloadFailed
    case unsupportedThumbnailOrigin
}

public extension SCTDataSession {
    func uploadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        fileUrl: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        SceytChatUIKit.shared.chatClient.upload(fileUrl: fileUrl) { _ in
        } completion: { url, error in
            if let url {
                completion(.success(url.absoluteString))
            } else {
                completion(.failure(error ?? SCTDataSessionError.thumbnailUploadFailed))
            }
        }
    }

    func downloadAttachmentThumbnail(
        for attachment: ChatMessage.Attachment,
        origin: String,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
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
    
    public func stop() {
        attachment.status = transferType == .upload ? .pauseUploading : .pauseDownloading
        action = .stop
        onAction?(.stop)
    }
    
    public func resume() {
        attachment.status = transferType == .upload ? .uploading : .downloading
        action = .resume
        onAction?(.resume)
    }
    
    public func startChecksum(_ completion: @escaping ((Bool) -> Void)) {
        checksumProvider.startChecksum(
            message: message,
            attachment: attachment) { [weak self] in
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
