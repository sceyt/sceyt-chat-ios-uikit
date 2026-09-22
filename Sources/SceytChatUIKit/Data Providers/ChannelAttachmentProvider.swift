//
//  ChannelAttachmentProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelAttachmentProvider: DataProvider {
    
    public var queryLimit = SceytChatUIKit.shared.config.queryLimits.attachmentListQueryLimit
    
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
        loadPrevAttachment(pageCompletion: { _, error in
            completion?(error)
        })
    }

    /// Same as `loadPrevAttachment(completion:)` but reports how many attachments the
    /// page returned. Callers that gate UI on "has the first page come back" must tell
    /// "the server has nothing" from "items came back and are still being merged into
    /// the database observer" — the second case must not reveal an empty state, because
    /// the observer's own change event is about to fill the list.
    ///
    /// A `nil` count means the request was not performed (a page was already in flight).
    open func loadPrevAttachment(
        pageCompletion: @escaping (Int?, Error?) -> Void
    ) {
        guard !defaultQuery.loading else {
            logger.debug("[MediaGallery] provider.loadPrevAttachment skipped — already loading channelId=\(channelId)")
            pageCompletion(nil, nil)
            return
        }
        defaultQuery.loadPrevious
        { (_, attachments, users, error) in
            guard let attachments
            else {
                if let error {
                    logger.error("[MediaGallery] query loadPrevious failed channelId=\(self.channelId): \(error)")
                } else {
                    logger.warn("[MediaGallery] query loadPrevious returned no attachments and no error channelId=\(self.channelId)")
                }
                pageCompletion(0, error)
                return
            }
            self.store(
                attachments: attachments,
                users: users
            ) { error in
                pageCompletion(attachments.count, error)
            }
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

    /// Loads the page of attachments older than `attachmentId` on a query of its own,
    /// reporting how many items the page returned like `loadPrevAttachment(pageCompletion:)`.
    ///
    /// `defaultQuery` is a cursor: a second `loadPrevious` on it is dropped while the
    /// first is still in flight, so a user who reaches the bottom of the list during the
    /// initial request gets no request at all and ends up waiting for two round-trips in
    /// sequence. A page anchored on an attachment id carries no cursor state, so every
    /// anchored page gets a fresh query and runs concurrently with whatever else is
    /// loading. Callers dedupe by anchor — see `ChannelAttachmentListViewModel`.
    open func loadPrevAttachment(
        before attachmentId: AttachmentId,
        pageCompletion: @escaping (Int, Error?) -> Void
    ) {
        let query = makeQuery()
        query.loadPrevious(attachmentId: attachmentId)
        { (_, attachments, users, error) in
            guard let attachments
            else {
                if let error {
                    logger.error("[MediaGallery] query loadPrevious(before: \(attachmentId)) failed channelId=\(self.channelId): \(error)")
                } else {
                    logger.warn("[MediaGallery] query loadPrevious(before: \(attachmentId)) returned no attachments and no error channelId=\(self.channelId)")
                }
                pageCompletion(0, error)
                return
            }
            self.store(
                attachments: attachments,
                users: users
            ) { error in
                pageCompletion(attachments.count, error)
            }
        }
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
            if let error {
                // Attachments are still written, but without their owner messages they
                // may not pass the list's predicate and stay invisible.
                logger.error("[MediaGallery] store: getMessages for \(messageIds.count) messages failed channelId=\(self.channelId), storing \(attachments.count) attachments without owner messages: \(error)")
            } else if let messages, messages.count != Set(messageIds).count {
                logger.warn("[MediaGallery] store: getMessages returned \(messages.count) of \(Set(messageIds).count) requested messages channelId=\(self.channelId)")
            }
            self.database.performWriteTask ({
                if let users {
                    $0.createOrUpdate(users: users)
                }
                $0.createOrUpdate(attachments: attachments, channelId: self.channelId)
                if let messages {
                    let existingDTOs = MessageDTO
                        .fetch(predicate: .init(format: "id IN %@", messages.map { $0.id }),
                               context: $0)
                    let idsSet = Set(existingDTOs.map { $0.id })
                    let previouslyUnlisted = Set(existingDTOs.filter { $0.unlisted }.map { $0.id })
                    $0.createOrUpdate(
                        messages: messages,
                        channelId: self.channelId
                    ).forEach {
                        if !idsSet.contains($0.id) {
                            $0.unlisted = true
                        } else if previouslyUnlisted.contains($0.id) {
                            $0.unlisted = true
                        }
                    }
                }
            }) { error in
                if let error {
                    logger.error("[MediaGallery] store: writing \(attachments.count) attachments to the database failed channelId=\(self.channelId): \(error)")
                } else {
                    logger.debug("[MediaGallery] store: wrote \(attachments.count) attachments (\(messages?.count ?? 0) messages) channelId=\(self.channelId)")
                }
                completion?(error)
            }
        }
    }
}
