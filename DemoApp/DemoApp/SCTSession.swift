//
//  SCTSession.swift
//  DemoApp
//
//  Created by Hovsep Keropyan on 09.03.23.
//

import UIKit
import SceytChat
import SceytChatUIKit

class SCTSession: NSObject, SCDataSession {
    
    static let `default` = SCTSession()
    
    let fileStorage: FileStorage = .init()
    
    func upload(attachment: ChatMessage.Attachment, taskInfo: SCDataSessionTaskInfo) {
        Task {
            guard var filePath = attachment.filePath else { return }
            let transferId = UUID().uuidString
            if attachment.type == "video" {
                let result = await SCUIKitComponents.videoProcessor.export(from: URL(fileURLWithPath: filePath))
                switch result {
                case .success(let success):
                    let path = self.fileStorage.store(transferId: transferId, fileName: success.lastPathComponent, file: success.path)
                    taskInfo.updateLocalFileLocation(newLocation: URL(fileURLWithPath: path))
                    filePath = path
                case .failure(let failure):
                    debugPrint(failure)
                }
            } else if attachment.type == "image" {
                if let builder = SCUIKitComponents.imageBuilder.init(imageUrl: URL(fileURLWithPath: filePath)) {
                    let imageSize = builder.imageSize
                    if !imageSize.isNan {
                        if let data = try? builder.resize(max: SCUIKitConfig.maximumImageAttachmentSize).jpegData(),
                           let newUrl = FileStorage.storeInTemporaryDirectory(data: data, filename: attachment.name ?? UUID().uuidString) {
                            let path = self.fileStorage.store(transferId: transferId, fileName: attachment.name, file: newUrl.path)
                            filePath = path
                            taskInfo.updateLocalFileLocation(newLocation: URL(fileURLWithPath: path))
                            fileStorage.updateThumbnailPath(transferId: transferId, filePath: attachment.filePath ?? "")
                            fileStorage.remove(path: attachment.filePath ?? "")
                        }
                    }
                }
            }
            
            let fileUrl = URL(fileURLWithPath: filePath)
            
            ChatClient.shared.upload(fileUrl: fileUrl) { pct in
                taskInfo.updateProgress(pct)
            } completion: { url, error in
                if error == nil {
                    taskInfo.success(origin: url!)
                } else {
                    taskInfo.failure(error: error)
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
    }
    
    func download(attachment: ChatMessage.Attachment, taskInfo: SCDataSessionTaskInfo) {
        guard let urlString = attachment.url,
                let url = URL(string: urlString)
        else { return }
        Session.download(url: url) { progress in
            taskInfo.setProgress(progress)
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
    
    func getFilePath(attachment: ChatMessage.Attachment) -> String? {
        if let filePath = attachment.filePath, FileManager.default.fileExists(atPath: filePath) {
            return filePath
        }
        if fileStorage.isFilePath(attachment.originUrl.path) {
            
            return attachment.originUrl.path
        }
        if let url = attachment.url {
            return fileStorage.path(transferId: url, fileName: attachment.name)
        }
        return nil
    }
    
    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? {
        if let path = getFilePath(attachment: attachment) {
            let thumbnailPath = fileStorage.thumbnailPath(filePath: path, imageSize: size)
            if fileStorage.isFilePath(thumbnailPath) {
                return thumbnailPath
            } else {
                var image: UIImage?
                if attachment.type == "image" {
                   image = UIImage(contentsOfFile: path)
                } else if attachment.type == "video" {
                    image = SCUIKitComponents.videoProcessor.copyFrame(url: URL(fileURLWithPath: path))
                } else if attachment.type == "file", URL(fileURLWithPath: path).isImage {
                    image = UIImage(contentsOfFile: path)
                }
                if let image,
                   let ib = try? SCUIKitComponents.imageBuilder.init(image: image).resize(max: size.maxSide),
                   let data = ib.jpegData() {
                    return Storage.storeData(data, filePath: thumbnailPath)?.path
                }
            }
        }
        return nil
    }
    
}
