//
//  MessageReactionProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class MessageReactionProvider: DataProvider {
    
    public var queryLimit = SceytChatUIKit.shared.config.queryLimits.reactionListQueryLimit
    public let messageId: MessageId
    public var cleanLocalReactionAfterFirstLoad: Bool = false
    private var isCleaned = false
    
    open private(set) var defaultQuery: ReactionListQuery!

    open func createDefaultQuery() {
        defaultQuery = ReactionListQuery
            .Builder(messageId: messageId)
            .limit(queryLimit)
            .build()
    }
    
    public required init(
        messageId: MessageId,
        query: ReactionListQuery? = nil) {
        self.messageId = messageId
        super.init()
        if let query {
            defaultQuery = query
        } else {
            createDefaultQuery()
        }
    }
    
    open func loadReactions(
        query: ReactionListQuery? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard chatClient.connectionState == .connected
        else { return }
        guard let query = (query ?? defaultQuery)
        else { return }
        if query.hasNext, !query.loading {
            query.loadNext { _, reactions, _ in
                guard let reactions = reactions
                else { return }
                self.store(
                    reactions: reactions,
                    completion: completion
                )
            }
        }
    }

    open func store(
        reactions: [Reaction],
        completion: ((Error?) -> Void)? = nil
    ) {
        guard !reactions.isEmpty
        else {
            completion?(nil)
            return
        }
        database.write {
            if self.cleanLocalReactionAfterFirstLoad, !self.isCleaned {
                self.isCleaned = true
                $0.deleteNotExistReactions(reactions)
            }
            let ids = $0.createOrUpdate(reactions: reactions)
                .map { $0.messageId }
            DispatchQueue
                .global(qos: .userInitiated)
                .async {
                    self.syncMessagesForReactions(messageIds: ids, reactions: reactions)
                }
        } completion: { error in
            logger.debug(error?.localizedDescription ?? "")
            completion?(error)
        }
    }
}

private extension MessageReactionProvider {
    
    func syncMessagesForReactions(messageIds: [Int64], reactions: [Reaction]) {
        guard !messageIds.isEmpty
        else { return }
        let channelId = try? database.read {
            MessageDTO.fetch(id: self.messageId, context: $0)?
                .channelId
        }.get()
        guard let channelId
        else { return }
        ChannelOperator(channelId: ChannelId(channelId))
            .getMessages(ids: messageIds.map { NSNumber(value: $0)})
        { messages, error in
            if let messages {
                self.database.write {
                    $0.createOrUpdate(messages: messages, channelId: ChannelId(channelId))
                    $0.createOrUpdate(reactions: reactions)
                } completion: { error in
                    
                }

            }
        }
    }
}
