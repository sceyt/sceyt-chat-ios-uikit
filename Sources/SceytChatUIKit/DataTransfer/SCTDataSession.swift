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
