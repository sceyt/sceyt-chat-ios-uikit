//
//  ChannelAttachmentProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelAttachmentProvider: Provider {
    
    public var queryLimit = UInt(10)
    
    public let channelId: ChannelId
    public let attachmentTypes: [String]
    public let channelOperator: ChannelOperator
    
    public required init(channelId: ChannelId, attachmentTypes: [String]) {
        self.channelId = channelId
        self.attachmentTypes = attachmentTypes
        channelOperator = .init(channelId: channelId)
        super.init()
    }
    
    public lazy var defaultQuery: AttachmentListQuery = {
        makeQuery()
    }()
    
    public func makeQuery() -> AttachmentListQuery {
        .Builder(channelId: channelId, types: attachmentTypes)
        .limit(queryLimit)
        .build()
    }
    
    open func loadNextAttachment(
        completion: ((Error?) -> Void)? = nil
    ) {
        loadNextAttachment(
            query: defaultQuery,
            completion: completion
        )
    }
    
    open func loadNextAttachment(
        query: AttachmentListQuery,
        completion: ((Error?) -> Void)? = nil
    ) {
        if !query.loading {
            query.loadNext
            { (_, attachments, users, error) in
                guard let attachments
                else {
                    completion?(error)
                    return
                }
                
                self.store(
                    attachments: attachments,
                    users: users,
                    completion: completion
                )
            }
        }
    }
    
    open func loadNextAttachment(
        after attachmentId: AttachmentId,
        completion: ((Error?) -> Void)? = nil
    ) {
        loadNextAttachment(
            query: defaultQuery,
            after: attachmentId,
            completion: completion
        )
    }
    
    open func loadNextAttachment(
        query: AttachmentListQuery,
        after attachmentId: AttachmentId,
        completion: ((Error?) -> Void)? = nil) {
            if !query.loading {
                query.loadNext(attachmentId: attachmentId)
                { (_, attachments, users, error) in
                    guard let attachments
                    else {
                        completion?(error)
                        return
                    }
                    self.store(
                        attachments: attachments,
                        users: users,
                        completion: completion
                    )
                }
            }
        }
    
    open func loadPrevAttachment(
        completion: ((Error?) -> Void)? = nil
    ) {
        loadPrevAttachment(
            query: defaultQuery,
            completion: completion
        )
    }
    
    open func loadPrevAttachment(
        query: AttachmentListQuery,
        completion: ((Error?) -> Void)? = nil
    ) {
        defaultQuery.loadPrevious
        { (_, attachments, users, error) in
            guard let attachments
            else {
                completion?(error)
                return
            }
            self.store(
                attachments: attachments,
                users: users,
                completion: completion
            )
        }
    }
    
    open func loadPrevAttachment(
        before attachmentId: AttachmentId,
        completion: ((Error?) -> Void)? = nil
    ) {
        loadPrevAttachment(
            query: defaultQuery,
            before: attachmentId,
            completion: completion
        )
    }
    
    open func loadPrevAttachment(
        query: AttachmentListQuery,
        before attachmentId: AttachmentId,
        completion: ((Error?) -> Void)? = nil) {
            if !query.loading {
                query.loadPrevious(attachmentId: attachmentId)
                { (_, attachments, users, error) in
                    guard let attachments
                    else {
                        completion?(error)
                        return
                    }
                    self.store(
                        attachments: attachments,
                        users: users,
                        completion: completion
                    )
                }
            }
        }
    
    open func loadNearAttachment(
        near attachmentId: AttachmentId,
        completion: ((Error?) -> Void)? = nil
    ) {
        loadNearAttachment(
            query: defaultQuery,
            near: attachmentId,
            completion: completion
        )
    }
    
    open func loadNearAttachment(
        query: AttachmentListQuery,
        near attachmentId: AttachmentId,
        completion: ((Error?) -> Void)? = nil) {
            query.loadNear(attachmentId: attachmentId)
            {  (_, attachments, users, error) in
                guard let attachments
                else {
                    completion?(error)
                    return
                }
                self.store(
                    attachments: attachments,
                    users: users,
                    completion: completion
                )
            }
        }
    
    open func store(
        attachments: [Attachment],
        users: [User]?,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard !attachments.isEmpty
        else {
            completion?(nil)
            return
        }
    
        let messageIds = attachments.map{ NSNumber(value: Int($0.messageId))}
        channelOperator.getMessages(
            ids: messageIds)
        { messages, error in
            self.database.write ({
                if let users {
                    $0.createOrUpdate(users: users)
                }
                $0.createOrUpdate(attachments: attachments, channelId: self.channelId)
                if let messages {
                    let exists = MessageDTO
                        .fetch(predicate: .init(format: "id IN %@", messages.map { $0.id }),
                               context: $0).map { $0.id }
                    let idsSet = Set(exists)
                    $0.createOrUpdate(
                        messages: messages,
                        channelId: self.channelId
                    ).forEach {
                        if !idsSet.contains($0.id) {
                            $0.unlisted = true
                        }
                    }
                }
                
            }) { error in
                completion?(error)
            }
        }
    }
}
