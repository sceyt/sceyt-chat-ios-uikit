//
//  SCTSession.swift
//  DemoApp
//
//  Created by Hovsep Keropyan on 09.03.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

open class SCTSession: NSObject, SCTDataSession {
    private lazy var queue = {
        $0.name = "com.sceyt.SCTUploadingQueue"
        $0.maxConcurrentOperationCount = 1
        return $0
    }(OperationQueue())
    
    private lazy var pendingOperations = NSMutableSet()
    
    open func add(_ operation: SCTUploadOperation) {
        if pendingOperations.contains(operation) {
            pendingOperations.remove(operation)
        }
        queue.addOperation(operation)
    }
    
    open func stop(_ operation: SCTUploadOperation) {
        operation.complete()
        pendingOperations.add(SCTUploadOperation(
            uuid: operation.uuid,
            attachment: operation.attachment,
            taskInfo: operation.taskInfo
        ))
    }
    
    open func resume(_ operation: SCTUploadOperation) {
        if let operation = pending(uuid: operation.uuid) {
            add(operation)
        } else {
            add(SCTUploadOperation(
                uuid: operation.uuid,
                attachment: operation.attachment,
                taskInfo: operation.taskInfo
            ))
        }
    }
    
    open func queuedOperation(uuid: String) -> SCTUploadOperation? {
        Self.default.queue.operations.first(where: { ($0 as? SCTUploadOperation)?.uuid == uuid }) as? SCTUploadOperation
    }
    
    open func pending(uuid: String) -> SCTUploadOperation? {
        Self.default.pendingOperations.first(where: { ($0 as? SCTUploadOperation)?.uuid == uuid }) as? SCTUploadOperation
    }
    
    public static let `default` = SCTSession()
    
    public let fileStorage: FileStorage = .init()
    
    open func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        let operation = SCTUploadOperation(
            attachment: attachment,
            taskInfo: taskInfo
        )
        add(operation)
        
        taskInfo.onAction = { [weak self] in
            guard let self else { return }
            
            switch $0 {
            case .stop:
                if let operation = queuedOperation(uuid: operation.uuid) {
                    stop(operation)
                }
            case .cancel:
                if let operation = queuedOperation(uuid: operation.uuid) {
                    operation.cancel()
                }
            case .resume:
                resume(operation)
            @unknown default:
                break
            }
            
            operation.complete()
        }
    }
    
    open func download(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        guard let urlString = attachment.url,
              let url = URL(string: urlString)
        else { return }
        Session.download(url: url) { progress in
            taskInfo.updateProgress(progress.fractionCompleted)
        } completion: { result in
            switch result {
            case .failure(let error):
                taskInfo.failure(error: error)
            case .success(let fileUrl):
                let transferId = url.deletingLastPathComponent().lastPathComponent
                let path = self.fileStorage.store(transferId: transferId, fileName: attachment.name, file: fileUrl.path)
                taskInfo.updateLocalFileLocation(newPath: path)
                taskInfo.success(origin: url)
            }
        }
        
        taskInfo.onAction = {
            switch $0 {
            case .stop:
                break
            case .cancel:
                break
            case .resume:
                break
            }
        }
    }
    
    open func getFilePath(attachment: ChatMessage.Attachment) -> String? {
        if let filePath = attachment.filePath, FileManager.default.fileExists(atPath: filePath) {
            return filePath
        }
        if fileStorage.isFilePath(attachment.originUrl.path) {
            return attachment.originUrl.path
        }
        if let stringUrl = attachment.url,
           let url = URL(string: stringUrl)
        {
            let transferId = url.deletingLastPathComponent().lastPathComponent
            return fileStorage.path(transferId: transferId, fileName: attachment.name)
        }
        return nil
    }
    
    open func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? {
        let scale = SceytChatUIKit.shared.config.displayScale
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        func makeThumbnail(file path: String, thumbnailPath: String) -> String? {
            var image: UIImage?
            if attachment.type == "image" {
                image = UIImage(contentsOfFile: path)
            } else if attachment.type == "video" {
                image = SCTUIKitComponents.videoProcessor.copyFrame(url: URL(fileURLWithPath: path))
            } else if attachment.type == "file", URL(fileURLWithPath: path).isImage {
                image = UIImage(contentsOfFile: path)
            }
            if let image,
               let ib = try? SCTUIKitComponents.imageBuilder.init(image: image).resize(max: newSize.maxSide),
               let data = ib.jpegData()
            {
                logger.debug("[thumbnail] 3 stored \(thumbnailPath)")
                return Storage.storeData(data, filePath: thumbnailPath)?.path
            }
            return nil
        }
        
        if let path = getFilePath(attachment: attachment) {
            let thumbnailPath = fileStorage.thumbnailPath(filePath: path, imageSize: newSize)
            if fileStorage.isFilePath(thumbnailPath) {
                logger.debug("[thumbnail] found file \(attachment.type)")
                return thumbnailPath
            }
            return makeThumbnail(file: path, thumbnailPath: thumbnailPath)
        } else if let path = attachment.filePath {
            let thumbnailPath = fileStorage.thumbnailPath(filePath: path, imageSize: newSize)
            return makeThumbnail(file: path, thumbnailPath: thumbnailPath)
        }
        return nil
    }
}

open class SCTUploadOperation: AsyncOperation {
    let attachment: ChatMessage.Attachment
    let taskInfo: SCTDataSessionTaskInfo
    private(set) var videoProcessInfo: SCVideoProcessInfo?
    public let fileStorage: FileStorage = .init()

    init(
        uuid: String = UUID().uuidString,
        attachment: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo
    ) {
        self.attachment = attachment
        self.taskInfo = taskInfo
        super.init(uuid)
    }
    
    override open func main() {
        taskInfo.startChecksum { [weak self] stored in
            guard let self else { return }
            if stored {
                self.complete()
            } else {
                self.startPreparing()
            }
        }
    }
    
    open func startPreparing() {
        Task {
            var canContinue: Bool { !isFinished && !isCancelled }
            
            guard var filePath = attachment.filePath else { return }
            logger.debug("check \(FileManager.default.fileExists(atPath: filePath))")
            let transferId = UUID().uuidString
            if attachment.type == "video" {
                let videoProcessInfo = SCVideoProcessInfo()
                let result = await SCTUIKitComponents.videoProcessor.export(from: filePath, processInfo: videoProcessInfo)
                switch result {
                case .success(let success):
                    let path = self.fileStorage.store(transferId: transferId, fileName: success.lastPathComponent, file: success.path)
                    taskInfo.updateLocalFileLocation(newLocation: URL(fileURLWithPath: path))
                    filePath = path
                case .failure(let error):
                    logger.errorIfNotNil(error, "")
                }
            } else if attachment.type == "image" {
                if let builder = SCTUIKitComponents.imageBuilder.init(imageUrl: URL(fileURLWithPath: filePath)) {
                    let imageSize = builder.imageSize
                    if !imageSize.isNan {
                        if let data = try? builder.resize(max: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.dimensionThreshold).jpegData(compressionQuality: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.compressionQuality),
                           let newUrl = FileStorage.storeInTemporaryDirectory(data: data, filename: attachment.name ?? UUID().uuidString)
                        {
                            let path = self.fileStorage.store(transferId: transferId, fileName: attachment.name, file: newUrl.path)
                            filePath = path
                            taskInfo.updateLocalFileLocation(newLocation: URL(fileURLWithPath: path))
                            fileStorage.updateThumbnailPath(transferId: transferId, filePath: attachment.filePath ?? "")
                            if attachment.filePath != filePath {
                                fileStorage.remove(path: attachment.filePath ?? "")
                            }
                        }
                    }
                }
            }
            
            guard canContinue else { return }
            
            startUploading(filePath: filePath)
        }
    }
    
    open func startUploading(filePath: String) {
        let fileUrl = URL(fileURLWithPath: filePath)
        SceytChatUIKit.shared.chatClient.upload(fileUrl: fileUrl) { [weak self] pct in
            self?.taskInfo.updateProgress(pct)
        } completion: { [weak self] url, error in
            guard let self else { return }
            if let error {
                self.taskInfo.failure(error: error)
            } else {
                self.taskInfo.success(origin: url!)
            }
            self.complete()
        }
    }
    
    override open func cancel() {
        videoProcessInfo?.cancel()
        super.cancel()
    }
    
    override open func complete() {
        videoProcessInfo?.cancel()
        super.complete()
    }
}
