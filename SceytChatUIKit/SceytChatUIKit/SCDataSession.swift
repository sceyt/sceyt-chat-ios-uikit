//
//  SCDataSession.swift
//  SceytChatUIKit
//

import Foundation

public protocol SCDataSession: NSObject {
    
    func upload(
        attachment: ChatMessage.Attachment,
        taskInfo: SCDataSessionTaskInfo
    )
    
    func download(
        attachment: ChatMessage.Attachment,
        taskInfo: SCDataSessionTaskInfo
    )
    
    func getFilePath(attachment: ChatMessage.Attachment) -> String?
    
    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String?
}

open class SCDataSessionTaskInfo: NSObject {
    
    @Published internal private(set) var event: Event?
    @Published public private(set) var action: Action?
    public var onAction: ((Action) -> Void)?
    
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
        attachment: ChatMessage.Attachment) {
        self.transferType = transferType
        self.message = message
        self.attachment = attachment
        super.init()
    }
    
    public func updateLocalFileLocation(newLocation: URL) {
        attachment.filePath = newLocation.path
        event = .updateLocalFileURL(newLocation)
    }
    
    public func updateLocalFileLocation(newPath: String) {
        attachment.filePath = newPath
        event = .updateLocalFileURL(URL(fileURLWithPath: newPath))
    }
    
    public func setProgress(_ progress: Progress) {
        attachment.transferProgress = progress.fractionCompleted
        event = .setProgress(progress)
    }
    
    public func updateProgress(_ progress: Double) {
        attachment.transferProgress = progress
        event = .updateProgress(progress)
    }
    
    public func failure(error: Error?) {
        event = .failure(error)
    }
    
    public func success(origin uri: String) {
        attachment.url = uri
        event = .successURI(uri)
    }
    
    public func success(origin url: URL) {
        attachment.url = url.path
        event = .successURL(url)
    }
}

internal extension SCDataSessionTaskInfo {
    enum Event {
        case updateLocalFileURL(URL)
        case setProgress(Progress)
        case updateProgress(Double)
        case failure(Error?)
        case successURI(String)
        case successURL(URL)
    }
    
    func cancel() {
        attachment.status = .pending
        action = .cancel
        onAction?(.cancel)
    }
    
    func stop() {
        attachment.status = transferType == .upload ? .pauseUploading : .pauseDownloading
        action = .stop
        onAction?(.stop)
    }
    
    func resume() {
        attachment.status = transferType == .upload ? .uploading : .downloading
        action = .resume
        onAction?(.resume)
    }
}

extension SCDataSessionTaskInfo {
    public enum Action {
        case cancel
        case stop
        case resume
    }
}
