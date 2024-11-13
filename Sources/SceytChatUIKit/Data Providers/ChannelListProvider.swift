//
//  ChannelListProvider.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

extension ChannelListProvider {
    public struct Config {
        public var types: [String]
        public var order: ChannelListOrder
        public var queryLimit: UInt
        public var queryParam: ChannelQueryParam
        
        public init(types: [String], order: ChannelListOrder, queryLimit: UInt, queryParam: ChannelQueryParam) {
            self.types = types
            self.order = order
            self.queryLimit = queryLimit
            self.queryParam = queryParam
        }
        
        public static var `default` = Config(
            types: [],
            order: SceytChatUIKit.shared.config.channelListOrder,
            queryLimit: SceytChatUIKit.shared.config.queryLimits.channelListQueryLimit,
            queryParam: {
                $0.userMessageReactionCount = 1
                $0.memberCount = 10
                return $0
            }(ChannelQueryParam())
        )
    }
}

open class ChannelListProvider: DataProvider {
    
    public var config: Config
    
    open private(set) var defaultQuery: ChannelListQuery!
    
    internal var onStoreChannels: (([Channel]) -> Void)?
    
    public required init(config: Config = .default) {
        self.config = config
        super.init()
        createDefaultQuery()
    }
    
    open func createDefaultQuery() {
        defaultQuery = ChannelListQuery
            .Builder()
            .types(config.types)
            .order(config.order)
            .limit(config.queryLimit)
            .requestParams(config.queryParam)
            .build()
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
        guard let query = (query ?? defaultQuery)
        else {
            completion?(nil)
            return
        }
        if query.hasNext, !query.loading {
            query.loadNext { _, channels, error in
                guard let channels = channels
                else {
                    completion?(error)
                    return
                }
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
        onStoreChannels?(channels)
        database.write {
            $0.createOrUpdate(channels: channels)
        } completion: { error in
            logger.errorIfNotNil(error, "Unable Store channels")
            completion?(error)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            channels.forEach { channel in
                guard let message = channel.lastMessage
                else { return }
                if !message.incoming || channel.userRole == nil || message.markerTotals?.contains(where: {$0.name == DefaultMarker.received.rawValue}) == true {
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
        database.performBgTask {
            ChannelDTO.totalUnreadMessageCount(context: $0)
        } completion: { result in
            switch result {
            case let .failure(error):
                logger.errorIfNotNil(error, "")
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
                    logger.errorIfNotNil(error, "")
                    completion([])
                }
            }
        }
    
    public class func fetchChannels(query: String, completion: @escaping ([ChatChannel]) -> Void) {
        database.read { context in
            let memberRequest = MemberDTO.fetchRequest()
            memberRequest.sortDescriptor = NSSortDescriptor(keyPath: \MemberDTO.channelId, ascending: false)
            let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let memberQuery = "(ANY user.firstName CONTAINS[cd] %@) OR (ANY user.lastName CONTAINS[cd] %@)"
            
            let queries = query.components(separatedBy: " ").compactMap { $0.isEmpty ? nil : $0 }
            memberRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: queries.map { NSPredicate(format: memberQuery, $0, $0) })
            let channelIds = MemberDTO.fetch(request: memberRequest, context: context).map { $0.channelId }
            
            let channelRequest = ChannelDTO.fetchRequest()
            channelRequest.predicate = NSPredicate(format: "type == %@ AND unsynched == NO AND id IN %@", SceytChatUIKit.shared.config.channelTypesConfig.direct, Set(channelIds))
            return ChannelDTO.fetch(request: channelRequest, context: context).map { $0.convert() }
        } completion: { result in
            switch result {
            case .success(let result):
                completion(result)
            case .failure(let error):
                logger.errorIfNotNil(error, "")
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
            self.database.read {
                var unownedDict = [ReactionId: (ChannelId, MessageId)]()
                let unownedIds = ReactionDTO.unownedReactionIds(reactionIds, context: $0)
                for id in unownedIds {
                    unownedDict[id] = dict[id]
                }
                return unownedDict
            } completion: { result in
                guard let unownedDict = try? result.get()
                else { return }
                for unowned in unownedDict {
                    let channelId = unowned.value.0
                    ChannelOperator(channelId: channelId)
                        .getMessages(ids: [NSNumber(value: unowned.value.1)])
                    { messages, error in
                        if let messages, !messages.isEmpty {
                            self.database.performWriteTask {
                                for message in messages {
                                    if MessageDTO.fetch(id: message.id, context: $0) == nil {
                                        $0.createOrUpdate(message: message, channelId: channelId)
                                            .unlisted = true
                                    }
                                }
                            } completion: { error in
                                if let error {
                                    logger.errorIfNotNil(error, "")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
