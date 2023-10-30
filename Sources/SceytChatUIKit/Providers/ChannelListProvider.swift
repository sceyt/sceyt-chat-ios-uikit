//
//  ChannelListProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelListProvider: Provider {

    public var queryLimit = UInt(20)
    public var queryListOrder = ChannelListOrder.lastMessage

    open private(set) var defaultQuery: ChannelListQuery!
    open var defaultParams: ChannelQueryParam
    public required override init() {
        defaultParams = ChannelQueryParam()
        defaultParams.userMessageReactionCount = 1
        defaultParams.memberCount = 10
        super.init()
        createDefaultQuery()
    }

    open func createDefaultQuery() {
        defaultQuery = ChannelListQuery
            .Builder()
            .order(queryListOrder)
            .limit(queryLimit)
            .requestParams(defaultParams)
            .build()
    }
    
    open func createDefaultQuery(params: ChannelQueryParam?) {
        let builder = ChannelListQuery
            .Builder()
            .order(queryListOrder)
            .limit(queryLimit)
        if let params {
            builder.requestParams(params)
        }
        defaultQuery = builder.build()
    }

    open func reloadChannels(
        query: ChannelListQuery? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        createDefaultQuery()
        loadChannels(query: query, completion: completion)
    }

    open func loadChannels(
        query: ChannelListQuery? = nil,
        completion: ((Error?) -> Void)? = nil
    ) {
        log.debug("[MARKER CHECK] loadChannels BEGIN")
        guard let query = (query ?? defaultQuery)
        else {
            completion?(nil)
            return
        }
        if query.hasNext, !query.loading {
            query.loadNext { _, channels, error in
                log.debug("[MARKER CHECK] loadChannels END")
                guard let channels = channels
                else {
                    completion?(error)
                    return
                }
                log.debug("[MARKER CHECK] loaded channels for query: \(query):\n\(channels.map { $0.subject })")
                self.store(
                    channels: channels,
                    completion: completion
                )
            }
        } else {
            completion?(nil)
        }
    }

    open func store(
        channels: [Channel],
        completion: ((Error?) -> Void)? = nil
    ) {
        database.write {
            $0.createOrUpdate(channels: channels)
        } completion: { error in
            log.errorIfNotNil(error, "Unable Store channels")
            completion?(error)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            channels.forEach { channel in
                guard let message = channel.lastMessage
                else { return }
                if channel.userRole == nil || message.markerTotals?.contains(where: {$0.name == DefaultMarker.received}) == true {
                    return
                }
                Components.channelMessageProvider.init(channelId: channel.id)
                    .markMessagesAsReceived(ids: [message.id])
            }
        }
    }
}

public extension ChannelListProvider {
    
    static func totalUnreadMessagesCount(_ completion: @escaping (Int) -> Void) {
        database.read {
            ChannelDTO.totalUnreadMessageCount(context: $0)
        } completion: { result in
            switch result {
            case let .failure(error):
                debugPrint(error)
            case let .success(sum):
                completion(sum)
            }
        }
    }
}

extension ChannelListProvider {
    
    public class func fetchPendingChannel(
        _ completion: @escaping ([(ChatChannel)]) -> Void) {
            database.read(resultQueue: .global()) {
                let request = ChannelDTO.fetchRequest()
                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.createdAt, ascending: true)
                request.predicate = .init(
                    format: "unsynched == YES AND lastMessage != nil")
                return ChannelDTO.fetch(request: request, context: $0)
                    .compactMap {
                        $0.convert()
                    }
            } completion: { result in
                switch result {
                case .success(let result):
                    completion(result)
                case .failure(let error):
                    debugPrint(error)
                    completion([])
                }
            }
        }
    
    public class func fetchChannels(query: String, completion: @escaping ([ChatChannel]) -> Void) {
        database.read { context in
            let request = ChannelDTO.fetchRequest()
            request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
            let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let contactQuery = "(ANY members.user.firstName CONTAINS[cd] %@) OR (ANY members.user.lastName CONTAINS[cd] %@)"
            let queries = query.components(separatedBy: " ").compactMap { $0.isEmpty ? nil : $0 }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: queries.map { NSPredicate(format: contactQuery, $0, $0) } + [
                NSPredicate(format: "type == %@ AND unsynched == NO", "direct")
            ])
            return ChannelDTO.fetch(request: request, context: context).map { $0.convert() }
        } completion: { result in
            switch result {
            case .success(let result):
                completion(result)
            case .failure(let error):
                debugPrint(error)
                completion([])
            }
        }
    }
    
    static func syncMessageForReactions(channels: [Channel]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var reactionIds = [ReactionId]()
            var dict = [ReactionId: (ChannelId, MessageId)]()
            for channel in channels {
                if let lastMessage = channel.lastMessage,
                   let reactions = channel.lastReactions,
                   !reactions.isEmpty,
                   let max = reactions.max(by: {$0.id > $1.id}),
                   max.messageId != lastMessage.id,
                    max.createdAt >= lastMessage.createdAt {
                    reactionIds.append(max.id)
                    dict[max.id] = (channel.id, max.messageId)
                }
            }
            let unownedDict = try? self.database.read {
                var unownedDict = [ReactionId: (ChannelId, MessageId)]()
                let unownedIds = ReactionDTO.unownedReactionIds(reactionIds, context: $0)
                for id in unownedIds {
                    unownedDict[id] = dict[id]
                }
                return unownedDict
            }.get()
            if let unownedDict {
                for unowned in unownedDict {
                    let channelId = unowned.value.0
                    ChannelOperator(channelId: channelId)
                        .getMessages(ids: [NSNumber(value: unowned.value.1)])
                    { messages, error in
                        if let messages, !messages.isEmpty {
                            self.database.write {
                                for message in messages {
                                    if MessageDTO.fetch(id: message.id, context: $0) == nil {
                                        $0.createOrUpdate(message: message, channelId: channelId)
                                            .unlisted = true
                                    }
                                }
                            } completion: { error in
                                if let error {
                                    debugPrint(error)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
