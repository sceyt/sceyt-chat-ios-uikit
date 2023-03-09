//
//  AttachmentTransfer.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat
import Combine

let fileProvider = AttachmentTransfer.default

open class AttachmentTransfer: Provider {
    
    public typealias ProgressBlock = (AttachmentProgress) -> Void
    
    var subscriptions = Set<AnyCancellable>()
    
    static var `default` = AttachmentTransfer()
    
    public override init() {
        super.init()
    }
    
    @Atomic private var cache = FileProviderCache()
    @Atomic private var taskGroups = [Int64: [SCDataSessionTaskInfo]]()
    
    private static func key(message: ChatMessage, attachment: ChatMessage.Attachment) -> String {
        let key = "\(message.id).\(message.tid).\(message.attachments?.firstIndex(of: attachment) ?? 0)"
        return key
    }
    
    open func progress(message: ChatMessage, attachment: ChatMessage.Attachment, block: @escaping ProgressBlock) {
        cache[Self.key(message: message, attachment: attachment)] = [_Obj(progress: block)]
    }
    
    open func uploadMessageAttachments(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        guard let attachments = attachments ?? message.attachments
        else {
            completion?(message, nil)
            return
        }
        
        if let dataSession = Components.dataSession {
            var tasks = [SCDataSessionTaskInfo]()
            let existTasks = taskGroups[message.id != 0 ? Int64(message.id) : message.tid]
            
            for (index, attachment) in attachments.enumerated() {
                guard attachment.filePath != nil
                else { continue }
                if existTasks?.contains(where: { $0.attachment.filePath == attachment.filePath }) == true {
                    continue
                }
                
                var mutableAttachment = attachment
                mutableAttachment.status = .uploading
                var attachments = message.attachments
                attachments?[index] = mutableAttachment
                
                let taskInfo = SCDataSessionTaskInfo(
                    transferType: .upload,
                    message: message,
                    attachment: mutableAttachment
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
            taskGroups[message.id != 0 ? Int64(message.id) : message.tid] = tasks
            handle(tasks: tasks, message: message, completion: completion)
            
        } else {
            completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
        }
    }
    
    open func downloadMessageAttachments(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment]? = nil,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
        guard let attachments = attachments ?? message.attachments
        else {
            completion?(message, nil)
            return
        }
        
        if let dataSession = Components.dataSession {
            var tasks = [SCDataSessionTaskInfo]()
            let existTasks = taskGroups[message.id != 0 ? Int64(message.id) : message.tid]
            var mutableAttachments = message.attachments
            for (index, attachment) in attachments.enumerated() {
                guard let url = attachment.url,
                      !url.isEmpty
                else { continue }
                if existTasks?.contains(where: { $0.attachment.url == attachment.url }) == true {
                    continue
                }
//                print("[PROFILE DOWN] 1", message.id, attachment.messageId, attachment.url)
                var mutableAttachment = attachment
                mutableAttachment.status = .downloading
                if mutableAttachments?.indices.contains(index) == true {
                    mutableAttachments?[index] = mutableAttachment
                }
                
                let taskInfo = SCDataSessionTaskInfo(
                    transferType: .download,
                    message: message,
                    attachment: mutableAttachment
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
                $0.update(chatMessage: message, attachments: mutableAttachments)
            }
//            print("[PROFILE DOWN] 2", message.id, attachments.first?.messageId, attachments.first?.url)
            taskGroups[message.id != 0 ? Int64(message.id) : message.tid] = tasks
            handle(tasks: tasks, message: message, completion: completion)
        } else {
            completion?(message, AttachmentTransferError.externalTransferrerNotImplemented)
        }
    }
    
    open func stopTransfer(message: ChatMessage, attachment: ChatMessage.Attachment) {
        guard let tasks = taskGroups[message.id != 0 ? Int64(message.id) : message.tid],
              let task = tasks.first(where: { $0.attachment == attachment })
        else { return }
        
        if var attachments = message.attachments,
            let index = attachments.firstIndex(where: { $0 == attachment }) {
            var mutableAttachment = attachments[index]
            switch task.transferType {
            case .download:
                mutableAttachment.status = .pauseDownloading
            case .upload:
                mutableAttachment.status = .pauseUploading
            }
            attachments[index] = mutableAttachment
            database.write {
                $0.update(chatMessage: message, attachments: attachments)
            } completion: { _ in
                task.stop()
            }
        }
    }
    
    open func resumeTransfer(message: ChatMessage, attachment: ChatMessage.Attachment) {
        if  taskGroups[message.id != 0 ? Int64(message.id) : message.tid] == nil {
            if attachment.filePath != nil, message.deliveryStatus == .pending {
                uploadMessageAttachments(message: message, attachments: [attachment])
            } else if attachment.url != nil {
                downloadMessageAttachments(message: message, attachments: [attachment])
            }
        }
        guard let tasks = taskGroups[message.id != 0 ? Int64(message.id) : message.tid],
              let task = tasks.first(where: { $0.attachment == attachment })
        else { return }
        if var attachments = message.attachments,
            let index = attachments.firstIndex(where: { $0 == attachment }) {
            var mutableAttachment = attachments[index]
            switch task.transferType {
            case .download:
                mutableAttachment.status = .downloading
            case .upload:
                mutableAttachment.status = .uploading
            }
            attachments[index] = mutableAttachment
            database.write {
                $0.update(chatMessage: message, attachments: attachments)
            } completion: { _ in
                task.resume()
            }
        }
        
    }
    
    open func transferStatus(
        message: ChatMessage,
        attachment: ChatMessage.Attachment
    ) -> ChatMessage.Attachment.TransferStatus? {
        guard let tasks = taskGroups[message.id != 0 ? Int64(message.id) : message.tid],
              let task = tasks.first(where: { $0.attachment == attachment })
        else { return nil }
        return task.attachment.status
    }
    
    private func handle(
        tasks: [SCDataSessionTaskInfo],
        message: ChatMessage,
        completion: ((ChatMessage?, Error?) -> Void)? = nil
    ) {
//        let mutableMessage = message
        var mutableAttachments = message.attachments
        let dispatchQueue = DispatchQueue(label: "com.sceytchat.uikit.task", qos: .userInitiated)
        let dispatchGroup = DispatchGroup()
        var uploadError: Error?
        for (index, taskInfo) in tasks.enumerated() {
            dispatchGroup.enter()
            taskInfo.$event
                .compactMap { $0 }
                .receive(on: dispatchQueue)
                .sink { event in
                    switch event {
                    case .updateProgress(let progress):
                        if let blocks = self.cache[Self.key(message: taskInfo.message, attachment: taskInfo.attachment)] {
                            let attachmentProgress = AttachmentProgress(
                                message: message,
                                attachment: taskInfo.attachment,
                                progress: progress
                            )
                            DispatchQueue.main.async {
                                blocks.forEach {
                                    $0.progress?(attachmentProgress)
                                }
                            }
                        }
                    case .setProgress(let progress):
                        if let blocks = self.cache[Self.key(message: taskInfo.message, attachment: taskInfo.attachment)] {
                            let attachmentProgress = AttachmentProgress(
                                message: message,
                                attachment: taskInfo.attachment,
                                progress: progress.fractionCompleted
                            )
                            DispatchQueue.main.async {
                                blocks.forEach {
                                    $0.progress?(attachmentProgress)
                                }
                            }
                        }
                    case .updateLocalFileURL(let url):
                        if var atch = mutableAttachments?[index] {
                            try? self.database.syncWrite {
                                $0.set(newFilePath: url.path, chatMessage: message, attachment: atch)
                            }
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
                            let fileSize = Storage.sizeOfItem(at: url)
                            if fileSize > 0 {
                                atch.uploadedFileSize = fileSize
                            }
                            mutableAttachments?.remove(at: index)
                            mutableAttachments?.insert(atch, at: index)
                            
                        }
                    case .successURL(let url):
                        let uri = url.absoluteString
                        if var atch = mutableAttachments?[index] {
                            atch.url = uri
                            atch.transferProgress = 1
                            atch.status = .done
                            mutableAttachments?.remove(at: index)
                            mutableAttachments?.insert(atch, at: index)
                        }
                        dispatchGroup.leave()
                    case .successURI(let uri):
                        if var atch = mutableAttachments?[index] {
                            atch.url = uri
                            atch.transferProgress = 1
                            atch.status = .done
                            mutableAttachments?.remove(at: index)
                            mutableAttachments?.insert(atch, at: index)
                        }
                        dispatchGroup.leave()
                    case .failure(let error):
                        debugPrint(error as Any)
                        uploadError = error
                        if var atch = mutableAttachments?[index] {
                            switch taskInfo.transferType {
                            case .download:
                                atch.status = .failedDownloading
                            case .upload:
                                atch.status = .failedUploading
                            }
                            mutableAttachments?.remove(at: index)
                            mutableAttachments?.insert(atch, at: index)
                        }
                        dispatchGroup.leave()
                    }
                    
                }.store(in: &subscriptions)
            
        }
        
        dispatchGroup.notify(queue: .global()) {
            var storedMessage: ChatMessage?
            try? self.database.syncWrite {
                storedMessage = $0.update(chatMessage: message, attachments: mutableAttachments)?.convert()
            }
//            print("[PROFILE DOWN] 3", mutableMessage.id, mutableMessage.attachments?.first?.messageId, mutableMessage.attachments?.first?.url)
            self.taskGroups[message.id != 0 ? Int64(message.id) : message.tid] = nil
            completion?(storedMessage ?? message, uploadError)
        }
    }
    
    func filePath(attachment: ChatMessage.Attachment) -> String? {
        guard let dataSession = Components.dataSession
        else {
            if attachment.filePath != nil {
                return attachment.filePath
            } else if let url = attachment.url {
                return Storage.filePath(for: url)
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
        let message: ChatMessage
        let attachment: ChatMessage.Attachment
        let progress: Double
        
        init(message: ChatMessage, attachment: ChatMessage.Attachment, progress: Double) {
            self.message = message
            self.attachment = attachment
            self.progress = progress
        }
        
    }
}

enum AttachmentTransferError: Error {
    case alreadyTransferring
    case externalTransferrerNotImplemented
}


private struct _Obj {
    var progress: AttachmentTransfer.ProgressBlock?
}

private typealias FileProviderCache = [String: [_Obj]]

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
