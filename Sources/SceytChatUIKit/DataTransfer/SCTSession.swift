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
    fileprivate lazy var queue = {
        $0.name = "com.sceyt.SCTUploadingQueue"
        $0.maxConcurrentOperationCount = 1
        return $0
    }(OperationQueue())
    
    fileprivate lazy var pendingOperations = NSMutableSet()
    
    public static let `default` = SCTSession()
    
    public let fileStorage: FileStorage = .init()
    
    open func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
        let operation = SCTUploadOperation(
            attachment: attachment,
            taskInfo: taskInfo
        )
        operation.completionBlock = { [weak self] in
            guard let self else { return }
            self.pendingOperations.remove(operation)
        }
        queue.addOperation(operation)
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
        let scale = SCTUIKitConfig.displayScale
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
                print("[thumbnail] 3 stored", thumbnailPath)
                return Storage.storeData(data, filePath: thumbnailPath)?.path
            }
            return nil
        }
        
        if let path = getFilePath(attachment: attachment) {
            let thumbnailPath = fileStorage.thumbnailPath(filePath: path, imageSize: newSize)
            if fileStorage.isFilePath(thumbnailPath) {
                print("[thumbnail] found file", attachment.type)
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
    private let attachment: ChatMessage.Attachment
    private let taskInfo: SCTDataSessionTaskInfo
    private var videoProcessInfo: SCVideoProcessInfo?
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
                complete()
            } else {
                startPreparing()
            }
        }
    }
    
    open func startPreparing() {
        var isStoped: Bool {
            switch taskInfo.action {
            case .stop:
                return true
            case .cancel:
                return true
            case .resume:
                return false
            default:
                return false
            }
        }
        
        var isRestarted = false
        var canContinue: Bool { !isStoped && !isRestarted }
        
        taskInfo.onAction = { [weak self] in
            if case .resume = $0 {
                if let operation = SCTSession.default.pendingOperations.first(where: { ($0 as? SCTUploadOperation)?.uuid == self?.uuid }) as? SCTUploadOperation {
                    operation.completionBlock = {
                        SCTSession.default.pendingOperations.remove(operation)
                    }
                    SCTSession.default.pendingOperations.remove(operation)
                    SCTSession.default.queue.addOperation(operation)
                }
            }
            guard let self else { return }
            log.debug("[SCTSTASK] onAction \($0)")
            switch $0 {
            case .stop:
                SCTSession.default.pendingOperations.add(SCTUploadOperation(
                    uuid: uuid,
                    attachment: self.attachment,
                    taskInfo: self.taskInfo
                ))
                self.videoProcessInfo?.cancel()
                self.complete()
            case .cancel:
                self.videoProcessInfo?.cancel()
                self.complete()
            case .resume:
                self.videoProcessInfo?.cancel()
                self.complete()
                isRestarted = true
            }
        }
        
        Task {
            let videoProcessInfo = SCVideoProcessInfo()
            guard var filePath = attachment.filePath else { return }
            print("check", FileManager.default.fileExists(atPath: filePath))
            let transferId = UUID().uuidString
            if attachment.type == "video" {
                let result = await SCTUIKitComponents.videoProcessor.export(from: filePath, processInfo: videoProcessInfo)
                switch result {
                case .success(let success):
                    let path = self.fileStorage.store(transferId: transferId, fileName: success.lastPathComponent, file: success.path)
                    taskInfo.updateLocalFileLocation(newLocation: URL(fileURLWithPath: path))
                    filePath = path
                case .failure(let error):
                    log.debug(error.localizedDescription)
                }
            } else if attachment.type == "image" {
                if let builder = SCTUIKitComponents.imageBuilder.init(imageUrl: URL(fileURLWithPath: filePath)) {
                    let imageSize = builder.imageSize
                    if !imageSize.isNan {
                        if let data = try? builder.resize(max: SCTUIKitConfig.maximumImageAttachmentSize).jpegData(),
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
        ChatClient.shared.upload(fileUrl: fileUrl) { [weak self] pct in
            self?.taskInfo.updateProgress(pct)
        } completion: { [weak self] url, error in
            guard let self else { return }
            if let error {
                taskInfo.failure(error: error)
            } else {
                taskInfo.success(origin: url!)
            }
            complete()
        }
    }
    
    override open func cancel() {
        videoProcessInfo?.cancel()
        super.cancel()
    }
}
