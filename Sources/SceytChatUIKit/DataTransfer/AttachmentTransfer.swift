//
//  AttachmentTransfer.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

let fileProvider = Components.attachmentTransfer.default

open class AttachmentTransfer: Provider {
    
    public typealias ProgressBlock = (AttachmentProgress) -> Void
    public typealias CompletionBlock = (AttachmentCompletion) -> Void
    
    private var subscriptions = Set<AnyCancellable>()
    private var tasksQueue = DispatchQueue(label: "com.sceytchat.uikit.attachmentTransfer")
    private var handleTaskQueue = DispatchQueue(label: "com.sceytchat.uikit.task")
    public static var `default` = Components.attachmentTransfer.init()
    
    required public override init() {
        super.init()
    }
    
    @Atomic private var cache = FileProviderCache()
    @Atomic private var uploadCallbackCache = CallbackCache()
    @Atomic private var downloadCallbackCache = CallbackCache()
    @Atomic private var progressCache = ProgressCache()
    @Atomic private var taskGroups = [Int64: [SCTDataSessionTaskInfo]]()
    
    public private(set) var uploadStopedOperations = [AsyncOperationBlock]()
    public var allTasks: [SCTDataSessionTaskInfo] {
        taskGroups.values.flatMap({ $0 })
    }
    
    private static func key(message: ChatMessage, attachment: ChatMessage.Attachment) -> String {
        let key = "\(message.id).\(message.tid).\(attachment.tid)"
        return key
    }
    
    open func taskFor(message: ChatMessage, attachment: ChatMessage.Attachment) -> SCTDataSessionTaskInfo? {
        if let tasks = taskGroups[message.id != 0 ? Int64(message.id) : message.tid] {
            return tasks.first(where: { $0.attachment == attachment })
        }
        return nil
    }
    
    open func progress(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        objectIdKey: String = "",
        block: @escaping ProgressBlock,
        completion: CompletionBlock? = nil
    ) {
        let key = Self.key(message: message, attachment: attachment)
        if cache[key] == nil {
            cache[key] = [_Obj(progress: block, completion: completion)]
        } else if cache[key]?.first(where: { !$0.idKey.isEmpty && $0.idKey == objectIdKey}) == nil {
            cache[key]?.append(_Obj(progress: block, completion: completion))
        }
    }
    
    open func currentProgressPercent(message: ChatMessage, attachment: ChatMessage.Attachment) -> Double? {
        progressCache[Self.key(message: message, attachment: attachment)]
    }
    
    open func removeProgressObserver(message: ChatMessage, attachment: ChatMessage.Attachment) {
        let key = Self.key(message: message, attachment: attachment)
        cache[key] = nil
        progressCache[key] = nil
    }
    
    open func uploadMessageAttachments(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        tasksQueue.async {
            guard let attachments = attachments ?? message.attachments,
                  !attachments.isEmpty
            else {
                completion?(message, nil)
                return
            }
            
            if let dataSession = Components.dataSession {
                var tasks = [SCTDataSessionTaskInfo]()
                let existTasks = self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid]
                for attachment in attachments {
                    guard attachment.filePath != nil
                    else { continue }
                    if existTasks?.contains(where: { $0.attachment.filePath == attachment.filePath }) == true {
                        let key = Self.key(message: message, attachment: attachment)
                        self.uploadCallbackCache[key] = [.init(callback: completion)]
                        continue
                    }
                    
                    attachment.status = .uploading
                    let taskInfo = SCTDataSessionTaskInfo(
                        transferType: .upload,
                        message: message,
                        attachment: attachment
                    )
                    
                    tasks.append(taskInfo)
                    dataSession.upload(
                        attachment: attachment,
                        taskInfo: taskInfo
                    )
                }
                guard !tasks.isEmpty else {
                    completion?(message, AttachmentTransferError.alreadyTransferring)
                    return
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: attachments)
                }
                self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid] = tasks
                self.handle(tasks: tasks, message: message, attachments: attachments) { message, error in
                    self.database.read {
                        var dto: MessageDTO?
                        if let message {
                            if message.id > 0 {
                                dto = MessageDTO.fetch(id: message.id, context: $0)
                            }
                            if dto == nil {
                                dto = MessageDTO.fetch(tid: message.tid, context: $0)
                            }
                        }
                        return dto != nil
                    } completion: { result in
                        if let existMessage = try? result.get(),
                            existMessage == true {
                            completion?(message, error)
                        } else {
                            completion?(nil, error)
                        }
                    }
                }
            } else {
                completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
            }
        }
    }
    
    @discardableResult
    open func downloadMessageAttachmentsIfNeeded(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) -> [ChatMessage.Attachment] {
        guard let attachments = attachments ?? message.attachments,
              !attachments.isEmpty
        else { return [] }
        let needsToDownloadAttachments = attachments.filter {
            $0.type != "link" &&
            $0.status != .pauseDownloading &&
            $0.status != .failedDownloading &&
            $0.status != .done &&
            Components.dataSession?.getFilePath(attachment: $0) == nil
        }
        guard !needsToDownloadAttachments.isEmpty
        else { return [] }
        downloadMessageAttachments(
            message: message,
            attachments: needsToDownloadAttachments,
            completion: completion)
        return needsToDownloadAttachments
    }
    
    open func downloadMessageAttachments(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        tasksQueue.async {
            guard let attachments = attachments ?? message.attachments
            else {
                completion?(message, nil)
                return
            }
            logger.verbose("[Attachment] downloadMessageAttachments \(attachments.map { $0.description })")
            if let dataSession = Components.dataSession {
                var tasks = [SCTDataSessionTaskInfo]()
                let existTasks = self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid]
                for (_, attachment) in attachments.enumerated() {
                    guard let url = attachment.url,
                          !url.isEmpty
                    else { continue }
                    if existTasks?.contains(where: { $0.attachment.url == attachment.url }) == true || fileProvider.filePath(attachment: attachment) != nil {
                        let key = Self.key(message: message, attachment: attachment)
                        self.downloadCallbackCache[key] = [.init(callback: completion)]
                        logger.verbose("[Attachment] downloadMessageAttachments: Task already exist \(attachments.map { $0.description })")
                        continue
                    }
                    attachment.status = .downloading
                    
                    let taskInfo = SCTDataSessionTaskInfo(
                        transferType: .download,
                        message: message,
                        attachment: attachment
                    )
                    
                    tasks.append(taskInfo)
                    dataSession.download(
                        attachment: attachment,
                        taskInfo: taskInfo
                    )
                }
                guard !tasks.isEmpty else {
                    completion?(message, AttachmentTransferError.alreadyTransferring)
                    return
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: attachments)
                }
                if let infos = self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid] {
                    logger.verbose("[Attachment] Download error \(infos.map { $0.attachment.url}) \(message.id)")
                    logger.verbose("[Attachment] Download error new \(tasks.map { $0.attachment.url}) \(tasks.map { $0.message.id})")
                }
                self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid] = tasks
                self.handle(tasks: tasks, message: message, attachments: attachments, completion: completion)
            } else {
                completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
            }
        }
    }
    
    open func stopTransfer(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: ((Bool) -> Void)? = nil) {
        tasksQueue.async {
            guard let task = self.taskFor(message: message, attachment: attachment)
            else {
                switch attachment.status {
                case .downloading:
                    attachment.status = .pauseDownloading
                case .uploading:
                    attachment.status = .pauseUploading
                default:
                    completion?(false)
                    return
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: [attachment])
                }
                completion?(true)
                return
            }
            
            if let attachments = message.attachments,
                let attachment = attachments.first(where: { $0.id == attachment.id }) {
                switch task.transferType {
                case .download:
                    attachment.status = .pauseDownloading
                case .upload:
                    attachment.status = .pauseUploading
                }
                self.database.write {
                    $0.update(chatMessage: message, attachments: attachments)
                } completion: { _ in
                    task.stop()
                }
                completion?(true)
                return
            }
            completion?(true)
        }
    }
    
    open func resumeTransfer(
        message: ChatMessage,
        attachment: ChatMessage.Attachment,
        completion: ((Bool) -> Void)? = nil) {
            tasksQueue.async {
                guard let task = self.taskFor(message: message, attachment: attachment)
                else {
                    completion?(false)
                    return
                }
                if let attachments = message.attachments,
                   let attachment = attachments.first(where: { $0.id == attachment.id }) {
                    switch task.transferType {
                    case .download:
                        attachment.status = .downloading
                    case .upload:
                        attachment.status = .uploading
                    }
                    self.database.write {
                        $0.update(chatMessage: message, attachments: attachments)
                    } completion: { _ in
                        task.resume()
                    }
                    completion?(true)
                    return
                }
                completion?(true)
                return
            }
        
    }
    
    open func transferStatus(
        message: ChatMessage,
        attachment: ChatMessage.Attachment
    ) -> ChatMessage.Attachment.TransferStatus? {
        guard let task = taskFor(message: message, attachment: attachment)
        else { return nil }
        return task.attachment.status
    }
    
    private func handle(
        tasks: [SCTDataSessionTaskInfo],
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        func onProgress( _ progress: Double, taskInfo: SCTDataSessionTaskInfo) {
            guard progress > 0
            else { return }
            let key = Self.key(message: taskInfo.message, attachment: taskInfo.attachment)
            let attachmentProgress = AttachmentProgress(
                message: taskInfo.message,
                attachment: taskInfo.attachment,
                progress: progress
            )
            logger.verbose("[Attachment] onProgress KEY \(key)")
            if let blocks = self.cache[key] {
                blocks.forEach {
                    $0.progress?(attachmentProgress)
                }
            }
            self.progressCache[key] = progress
        }
        
        func onCompletion(
            taskInfo: SCTDataSessionTaskInfo,
            attachment: ChatMessage.Attachment,
            error: Error? = nil
        ) {
            let key = Self.key(message: taskInfo.message, attachment: taskInfo.attachment)
            logger.verbose("[Attachment] onCompletion KEY \(key)")
            if let blocks = self.cache[key] {
                let attachmentCompletion = AttachmentCompletion(
                    message: message,
                    attachment: attachment,
                    error: error
                )
                blocks.forEach {
                    $0.completion?(attachmentCompletion)
                }
            }
        }
        
        for (index, taskInfo) in tasks.enumerated() {
            taskInfo.onEvent = { [weak self, index] event in
                    guard let self else { return }
                    switch event {
                    case .updateProgress(let progress):
                        onProgress(progress, taskInfo: taskInfo)
                    case .updateLocalFileURL(let url, let filePath):
                        logger.verbose("[Attachment] Handle updateLocalFileURL \(url)")
                        if attachments.indices.contains(index) {
                            let atch = attachments[index]
                            logger.verbose("[Attachment] Handle updateLocalFileURL found \(String(describing: atch.url))")
                            if let builder = Components.imageBuilder.init(imageUrl: url) {
                                if let decodedMetadata = atch.imageDecodedMetadata {
                                    atch.metadata =
                                    ChatMessage.Attachment.Metadata(
                                        width: Int(builder.imageSize.width),
                                        height: Int(builder.imageSize.height),
                                        thumbnail: decodedMetadata.thumbnail,
                                        duration: decodedMetadata.duration
                                    ).build()
                                } else if let decodedMetadata = atch.voiceDecodedMetadata {
                                    atch.metadata =
                                    ChatMessage.Attachment.Metadata(
                                        width: Int(builder.imageSize.width),
                                        height: Int(builder.imageSize.height),
                                        thumbnail: decodedMetadata.thumbnail,
                                        duration: decodedMetadata.duration
                                    ).build()
                                }
                            }
                            atch.name = url.lastPathComponent
                            atch.filePath = url.path
                            let fileSize = Components.storage.sizeOfItem(at: url)
                            if fileSize > 0 {
                                atch.uploadedFileSize = fileSize
                            }
                            taskInfo.attachment = atch
                            self.database.write {
                                if let filePath {
                                    logger.verbose("[Attachment] Handle updateLocalFileURL file by filePath \(String(describing: atch.url))")
                                    $0.updateAttachment(with: filePath, chatMessage: message, attachment: atch)
                                } else {
                                    logger.verbose("[Attachment] Handle updateLocalFileURL file by [] \(String(describing: atch.url))")
                                    $0.update(chatMessage: message, attachments: [atch])
                                }
                            }
                        }
                    case .successURL(let url):
                        logger.verbose("[Attachment] Handle successURL  \(url)")
                        let uri = url.absoluteString
                        if attachments.indices.contains(index) {
                            let atch = attachments[index]
                            logger.verbose("[Attachment] Handle successURL  found \(String(describing: atch.url))")
                            atch.url = uri
                            atch.transferProgress = 1
                            atch.status = .done
                            onCompletion(taskInfo: taskInfo, attachment: atch)
                        }
                        logger.verbose("[Attachment] receive successURL \(uri)")
                        didEndTask(taskInfo: taskInfo, error: nil)
                    case .successURI(let uri):
                        logger.verbose("[Attachment] Handle successURI  \(uri)")
                        if attachments.indices.contains(index) {
                            let atch = attachments[index]
                            logger.verbose("[Attachment] Handle successURI  found \(String(describing: atch.url))")
                            atch.url = uri
                            atch.transferProgress = 1
                            atch.status = .done
                            onCompletion(taskInfo: taskInfo, attachment: atch)
                        }
                        logger.verbose("[Attachment] receive successURI \(uri)")
                        didEndTask(taskInfo: taskInfo, error: nil)
                    case .failure(let error):
                        logger.errorIfNotNil(error, "[Attachment] transfer")
                        if attachments.indices.contains(index) {
                            let atch = attachments[index]
                            logger.verbose("[Attachment] Handle failure  found \(String(describing: atch.url))")
                            switch taskInfo.transferType {
                            case .download:
                                if atch.status != .pauseDownloading {
                                    atch.status = .failedDownloading
                                }
                            case .upload:
                                if atch.status != .pauseUploading {
                                    atch.status = .failedUploading
                                }
                            }
                            onCompletion(taskInfo: taskInfo, attachment: atch, error: error)
                        }
                        logger.errorIfNotNil(error, "[Attachment] receive failure")
                        didEndTask(taskInfo: taskInfo, error: error)
                    }
                }
        }
        
        func didEndTask(taskInfo: SCTDataSessionTaskInfo, error: Error?) {
            let key = Self.key(message: taskInfo.message, attachment: taskInfo.attachment)
            var storedMessage: ChatMessage?
            self.database.write(resultQueue: .global()) {
                storedMessage = $0.update(chatMessage: message, attachments: attachments)?.convert()
                for attachment in attachments where attachment.url != nil {
                    $0.updateChecksum(data: attachment.url!, messageTid: message.tid, attachmentTid: attachment.tid)
                }
            } completion: { _ in
                completion?(storedMessage ?? message, error)
                switch taskInfo.transferType {
                case .upload:
                    if let callbacks = self.uploadCallbackCache[key] {
                        for callback in callbacks {
                            logger.verbose("[Attachment] Handle didEndTask  uploadCallbackCache \(callback)")
                            callback.callback?(storedMessage ?? message, error)
                        }
                        self.uploadCallbackCache[key] = nil
                    }
                case .download:
                    if let callbacks = self.downloadCallbackCache[key] {
                        for callback in callbacks {

                            logger.verbose("[Attachment] Handle didEndTask  downloadCallbackCache \(callback)")
                            callback.callback?(storedMessage ?? message, error)
                        }
                        self.downloadCallbackCache[key] = nil
                    }
                }
            }
            if let taskInfos = self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid] {
                logger.verbose("[Attachment] Handle didEndTask  taskInfos \(taskInfos.map { $0.attachment.url})")
                self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid] = nil
            }
            
        }
    }
    
    func filePath(attachment: ChatMessage.Attachment) -> String? {
        guard let dataSession = Components.dataSession
        else {
            if attachment.filePath != nil {
                return attachment.filePath
            } else if let url = attachment.url {
                return Components.storage.filePath(for: url)
            }
            return nil
        }
        return dataSession.getFilePath(attachment: attachment)
    }
    
    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? {
        guard let dataSession = Components.dataSession
        else { return nil }
        return dataSession.thumbnailFile(for: attachment, preferred: size)
    }
}

extension AttachmentTransfer {
    public class AttachmentProgress {
        public let message: ChatMessage
        public let attachment: ChatMessage.Attachment
        public let progress: Double
        
        init(message: ChatMessage,
             attachment: ChatMessage.Attachment,
             progress: Double) {
            self.message = message
            self.attachment = attachment
            self.progress = progress
        }
    }
    
    public class AttachmentCompletion {
        public let message: ChatMessage
        public let attachment: ChatMessage.Attachment
        public let error: Error?
        
        init(message: ChatMessage,
             attachment: ChatMessage.Attachment,
             error: Error? = nil
        ) {
            self.message = message
            self.attachment = attachment
            self.error = error
        }
        
    }
}

enum AttachmentTransferError: Error {
    case alreadyTransferring
    case externalTransferrerNotImplemented
}


private struct _Obj {
    var progress: AttachmentTransfer.ProgressBlock?
    var completion: AttachmentTransfer.CompletionBlock?
    var idKey: String = ""
}

private struct _CallBack {
    var callback: ((ChatMessage?, Error?) -> Void)? = nil
}

private typealias FileProviderCache = [String: [_Obj]]
private typealias ProgressCache = [String: Double]
private typealias CallbackCache = [String: [_CallBack]]

private extension FileProviderCache {
    
    subscript(key: String) -> [_Obj] {
        get {
            self[key] ?? []
        }
        set {
            if self[key] == nil {
                self[key] = []
            }
            self[key] = self[key]?.filter { $0.progress != nil }
            self[key]?.append(contentsOf: newValue)
        }
    }
}

private extension CallbackCache {
    
    subscript(key: String) -> [_CallBack] {
        get {
            self[key] ?? []
        }
        set {
            if self[key] == nil {
                self[key] = []
            }
            self[key] = self[key]?.filter { $0.callback != nil }
            self[key]?.append(contentsOf: newValue)
        }
    }
}
