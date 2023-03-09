//
//  AWSSession.swift
//  DemoApp
//
//

import UIKit
import SceytChatUIKit
import AWSS3
import AWSCore

class AWSSession: NSObject, SCDataSession {
    
    static let `default` = AWSSession()
    private(set) var config: Config!
    
    let fileStorage: FileStorage = .init()
    
    private override init() {
        super.init()
        AWSDDLog.sharedInstance.logLevel = .all
    }
    
    func configure(config: Config = .init()) {
        self.config = config
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: config.region, identityPoolId: config.poolId)
        if let serviceConfig = AWSServiceConfiguration(region: config.region, credentialsProvider: credentialsProvider) {
            AWSServiceManager.default().defaultServiceConfiguration = serviceConfig
            let utilityConfiguration = AWSS3TransferUtilityConfiguration()
            utilityConfiguration.bucket = config.bucket
            AWSS3TransferUtility.register(
                with: serviceConfig,
                transferUtilityConfiguration: utilityConfiguration,
                forKey: config.s3TransferUtilityKey
            )
        }
    }
    
    static func interceptApplication(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String) async {
        await AWSS3TransferUtility.interceptApplication(application, handleEventsForBackgroundURLSession: identifier)
    }
    
    func upload(
        attachment: ChatMessage.Attachment,
        taskInfo: SCDataSessionTaskInfo
    ) {
        
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
                    debugPrint("[AWSS3] videoProcessor success", success)
                case .failure(let failure):
                    debugPrint("[AWSS3] videoProcessor failure", failure)
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
                            debugPrint("[AWSS3] imageBuilder success", path)
                        }
                    }
                }
            }
            debugPrint("[AWSS3] UPLOADING", filePath)
            guard let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: config.s3TransferUtilityKey)
            else { return }
            
            
            let fileUrl = URL(fileURLWithPath: filePath)
            let completionHandler: AWSS3TransferUtilityMultiPartUploadCompletionHandlerBlock = {(task, error)-> Void in
                debugPrint("[AWSS3] completionHandler", task, error as Any)
                if error == nil {
    //                let path = self.fileStorage.store(transferId: transferId, fileName: attachment.name, file: fileUrl.path)
    //                taskInfo.updateLocalFileLocation(newPath: path)
                    taskInfo.success(origin: transferId)
                } else {
                    taskInfo.failure(error: error)
                }
            }
            
            let progressBlock: AWSS3TransferUtilityMultiPartProgressBlock = {(task, progress)-> Void in
                debugPrint("[AWSS3] progressBlock", task.transferID, progress.fractionCompleted)
                taskInfo.setProgress(progress)
            }
            
            let multipartExpression = AWSS3TransferUtilityMultiPartUploadExpression()
            
            multipartExpression.progressBlock = progressBlock
            
            let task = transferUtility.uploadUsingMultiPart(
                fileURL: fileUrl,
                key: s3Key(key: transferId),
                contentType: fileUrl.mimeType(),
                expression: multipartExpression,
                completionHandler: completionHandler
            )
            debugPrint("[AWSS3] end", task, task.isCancelled, task.isFaulted)
            
            taskInfo.onAction = {
                switch $0 {
                case .stop:
                    task.result?.suspend()
                case .cancel:
                    task.result?.cancel()
                case .resume:
                    task.result?.resume()
                }
            }
        }
    }
    
    func download(
        attachment: ChatMessage.Attachment,
        taskInfo: SCDataSessionTaskInfo
    ) {
        
        Task {
            guard let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: config.s3TransferUtilityKey),
                  let transferId = attachment.url
            else { return }
            
            let progressBlock: AWSS3TransferUtilityProgressBlock = {(task, progress)-> Void in
                debugPrint("[AWSS3] progressBlock", task.transferID, progress.fractionCompleted)
                taskInfo.setProgress(progress)
            }
            let completionHandler : AWSS3TransferUtilityDownloadCompletionHandlerBlock = {(task, url, data, error) -> Void in
                if let url, error == nil {
                    debugPrint("[AWSS3] completionHandler", url, FileManager.default.fileExists(atPath: url.path))
                    let path = self.fileStorage.store(transferId: transferId, fileName: attachment.name, file: url.path)
                    taskInfo.updateLocalFileLocation(newPath: path)
                    taskInfo.success(origin: transferId)
                } else {
                    taskInfo.failure(error: error)
                }
            }
            let location = URL(fileURLWithPath: fileStorage.createPath(transferId: transferId, fileName: attachment.name))
            debugPrint("[AWSS3] file download at location", location.path)
            let expression = AWSS3TransferUtilityDownloadExpression()
            expression.progressBlock = progressBlock
            expression.setValue(s3Key(key: transferId), forRequestHeader: config.s3RequestHeaderTag)
            let task = transferUtility.download(
                to: location,
                key: s3Key(key: transferId),
                expression: expression,
                completionHandler: completionHandler
            )
            taskInfo.onAction = {
                switch $0 {
                case .stop:
                    task.result?.suspend()
                case .cancel:
                    task.result?.cancel()
                case .resume:
                    task.result?.resume()
                }
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
    
    private func s3Key(key: String) -> String {
        config.s3ResourceRoot + "/" + key
    }
    
    private func localKey(key: String) -> String {
        let prefix = config.s3ResourceRoot + "/"
        if key.hasPrefix(prefix) {
            return String(key.dropFirst(prefix.count))
        }
        return key
    }
    
}

extension AWSSession {
    
    struct Config {
        var region = AWSRegionType.EUWest2
        var poolId = "pool-id"
        var providerName = "example.provider"
        var s3TransferUtilityKey = "Key"
        var s3RequestHeaderTag = "Tag"
        var s3ResourceRoot = "public"
        var bucket = "bucket"
    }
}


class FileStorage: Storage {
    
    static let `default` = FileStorage()
    
    var fileManager: FileManager { FileManager.default }
    
    static var documentDirectory: URL? = {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            return URL(fileURLWithPath: path)
        }
        return nil
    }()
    
    lazy var storagePath: String = {
        let tmp = NSTemporaryDirectory()
        guard let documentDirectory = Self.documentDirectory
        else { return tmp }
        let cachePath = documentDirectory.appendingPathComponent("app_files").path
        if fileManager.fileExists(atPath: cachePath) {
            return cachePath
        }
        do {
            try fileManager.createDirectory(atPath: cachePath, withIntermediateDirectories: false, attributes: nil)
            return cachePath
        } catch {
            return tmp
        }
    }()
    
    lazy var thumbnailPath: String = {
        let path = URL(fileURLWithPath: storagePath).appendingPathComponent("thumbnails").path
        if fileManager.fileExists(atPath: path) {
            return path
        }
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        } catch {

        }
        return path
    }()
    
    func store(transferId: String, fileName: String?, file path: String) -> String {
        var newPath = filePath(transferId: transferId)
        if let fileName {
            do {
                try fileManager.createDirectory(at: URL(fileURLWithPath: newPath), withIntermediateDirectories: true, attributes: nil)
                newPath = (newPath as NSString).appendingPathComponent(fileName)
            } catch {
                debugPrint("store error", error)
            }
        }
        do {
            guard path != newPath
            else { return path }
            if fileManager.isDeletableFile(atPath: path) {
                try fileManager.moveItem(atPath: path, toPath: newPath)
            } else {
                try fileManager.copyItem(atPath: path, toPath: newPath)
            }
        } catch {
            debugPrint(error)
            return path
        }
        return newPath
    }
    
    func path(transferId: String, fileName: String?) -> String? {
        var path = filePath(transferId: transferId)
        if let fileName {
            path = (path as NSString).appendingPathComponent(fileName)
        }
        if fileManager.fileExists(atPath: path) {
            return path
        }
        return nil
    }
    
    func createPath(transferId: String, fileName: String?) -> String {
        var path = filePath(transferId: transferId)
        if let fileName {
            do {
                try fileManager.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true, attributes: nil)
                path = (path as NSString).appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: path) {
                    try fileManager.removeItem(atPath: path)
                }
            } catch {
                debugPrint("store error", error)
            }
        }
        return path
    }
    
    func thumbnailPath(filePath: String, imageSize: CGSize) -> String {
        var tmPath = filePath
        if filePath.hasPrefix(storagePath) {
            tmPath = String(filePath.dropFirst(storagePath.count))
            if tmPath.hasPrefix("/") {
                tmPath = String(tmPath.dropFirst(1))
            }
        }
        let folder = "\(Int(imageSize.width))x\(Int(imageSize.height))"
        var tmUrl = URL(fileURLWithPath: thumbnailPath).appendingPathComponent(folder).appendingPathComponent(tmPath)
        do {
            try fileManager.createDirectory(at: tmUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        } catch {
            debugPrint("thumbnailPath error", error)
        }
        return tmUrl.path
    }
    
    func updateThumbnailPath(transferId: String, filePath: String) {
        var tmPath = filePath
        if filePath.hasPrefix(storagePath) {
            tmPath = String(filePath.dropFirst(storagePath.count))
            if tmPath.hasPrefix("/") {
                tmPath = String(tmPath.dropFirst(1))
            }
        }
        try? fileManager.contentsOfDirectory(atPath: thumbnailPath)
            .forEach { path in
                var isDir: ObjCBool = false
                let subDir = URL(fileURLWithPath: thumbnailPath).appendingPathComponent(path)
                guard fileManager.fileExists(atPath: subDir.path, isDirectory: &isDir), isDir.boolValue
                else { return }
                let tmpUrl = URL(fileURLWithPath: thumbnailPath)
                    .appendingPathComponent(path)
                    .appendingPathComponent(tmPath)
                if fileManager.fileExists(atPath: tmpUrl.path) {
                    let newTmpUrl = URL(fileURLWithPath: thumbnailPath)
                        .appendingPathComponent(path)
                        .appendingPathComponent(transferId)
                        .appendingPathComponent(tmPath)
                    do {
                        try? fileManager.createDirectory(at: newTmpUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                        try fileManager.copyItem(at: tmpUrl, to: newTmpUrl)
                        try fileManager.removeItem(at: tmpUrl)
                    } catch {
                        debugPrint(error)
                    }
                }
        }
    }
    
    func remove(path: String) {
        try? fileManager.removeItem(atPath: path)
    }
    
    func filePath(transferId: String) -> String {
        (storagePath as NSString).appendingPathComponent(transferId)
    }
    
    func isFilePath(_ path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
    
}
