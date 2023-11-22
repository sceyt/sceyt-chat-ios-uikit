//
//  AttachmentLoader.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class AttachmentLoader: NSObject {
    
    public static var `default` = AttachmentLoader()
    
    open private(set) var cache = Cache<MessageId, [PublisherItem]>()
    
    open func publisherItem(attachment: ChatMessage.Attachment, message: ChatMessage) -> PublisherItem? {
        cache[message.id]?.first(where: { $0.attachment == attachment })
    }
    
    open func fileLocalStorageUrl(attachment: ChatMessage.Attachment, message: ChatMessage) -> URL? {
        if let fileUrl = cache[message.id]?.first(where: { $0.attachment == attachment })?.fileUrl {
            return fileUrl
        }
        if let filePath = Components.storage.filePath(for: attachment) {
            return URL(fileURLWithPath: filePath)
        }
        return nil
    }
    
    open func add(attachments: [ChatMessage.Attachment], message: ChatMessage) -> [PublisherItem] {
        
        var newItems = [PublisherItem]()
        var allItems = [PublisherItem]()
        let cachedItems = cache[message.id]
        for attachment in attachments {
            if let items = cachedItems, let old = items.first(where: { $0.attachment == attachment }) {
                allItems.append(old)
            } else {
                newItems.append(PublisherItem(message: message, attachment: attachment))
                allItems.append(newItems.last!)
            }
            
        }
        if !newItems.isEmpty {
            if cache[message.id] == nil {
                cache[message.id] = newItems
            } else {
                cache[message.id]?.append(contentsOf: newItems)
            }
            newItems.forEach { start(item: $0) }
        }
        
        return allItems
    }
    
    open func remove(attachments: [ChatMessage.Attachment] = [], messageId: MessageId) {
        if attachments.isEmpty {
            cache[messageId] = nil
        } else {
            attachments.forEach { attachment in
                cache[messageId]?.removeAll(where: { $0.attachment == attachment })
            }
        }
    }
    
    private func start(item: PublisherItem) {
        
        if let upload = MessageAttachmentUploadInfo.default.item(key: MessageAttachmentUploadInfo.Key(item.message.tid)) {
            upload.onProgress = { (_, _, pct) in
                item.progress = pct
            }
            upload.onCompletion = { (_, _, url, _) in
                item.fileUrl = url
                item.progress = 1
            }
        } else {
            item.cancellable = Session
                .loadFile(url: URL(string: item.attachment.url!)!) {progress in
                    item.progress = Double(progress.fractionCompleted)
                } completion: {result in
                    switch result {
                    case .success(let url):
                        item.fileUrl = url
                        item.progress = 1
                    case .failure(let error):
                        item.progress = 1
                        logger.debug("Download error \(error)")
                    }
                }
        }
    }
    
    open func removeCache() {
        cache.removeAll()
    }
}

extension AttachmentLoader {
    
    public class PublisherItem: NSObject {
        public let message: ChatMessage
        public let attachment: ChatMessage.Attachment
        @objc dynamic var progress: Double = 0
        public var fileUrl: URL?
        public var cancellable: Cancellable?
        
        public required init(message: ChatMessage, attachment: ChatMessage.Attachment) {
            self.message = message
            self.attachment = attachment
            if let filePath = attachment.filePath {
                fileUrl = URL(fileURLWithPath: filePath)
            }
        }
    }
}
