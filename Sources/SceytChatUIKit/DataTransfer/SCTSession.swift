//
//  SCTSession.swift
//  DemoApp
//
//  Created by Hovsep Keropyan on 09.03.23.
//

import UIKit
import SceytChat

open class SCTSession: NSObject, SCTDataSession {
    
    public static let `default` = SCTSession()
    
    public let fileStorage: FileStorage = .init()
    
    open func upload(attachment: ChatMessage.Attachment, taskInfo: SCTDataSessionTaskInfo) {
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
                case .failure(let failure):
                    debugPrint(failure)
                }
            } else if attachment.type == "image" {
                if let builder = SCTUIKitComponents.imageBuilder.init(imageUrl: URL(fileURLWithPath: filePath)) {
                    let imageSize = builder.imageSize
                    if !imageSize.isNan {
                        if let data = try? builder.resize(max: SCTUIKitConfig.maximumImageAttachmentSize).jpegData(),
                           let newUrl = FileStorage.storeInTemporaryDirectory(data: data, filename: attachment.name ?? UUID().uuidString) {
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
            
            let fileUrl = URL(fileURLWithPath: filePath)
            
            await withCheckedContinuation { continuation in
                ChatClient.shared.upload(fileUrl: fileUrl) { pct in
                    taskInfo.updateProgress(pct)
                } completion: { url, error in
                    if error == nil {
                        taskInfo.success(origin: url!)
                    } else {
                        taskInfo.failure(error: error)
                    }
                    continuation.resume()
                }
            }

            taskInfo.onAction = {
                switch $0 {
                case .stop:
                    break
                case .cancel:
                    videoProcessInfo.cancel()
                case .resume:
                    break
                }
            }
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
            let url = URL(string: stringUrl) {
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
               let data = ib.jpegData() {
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
