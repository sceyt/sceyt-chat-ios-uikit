//
//  ChannelListProvider.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelListProvider: Provider {

    public static var queryLimit = UInt(20)
    public static var queryListOrder = ChannelListOrder.lastMessage

    open private(set) var defaultQuery: ChannelListQuery!

    public required override init() {
        super.init()
        createDefaultQuery()
    }

    open func createDefaultQuery() {
        defaultQuery = ChannelListQuery
            .Builder()
            .order(Self.queryListOrder)
            .limit(Self.queryLimit)
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
        guard chatClient.connectionState == .connected
        else { return }
        guard let query = (query ?? defaultQuery)
        else { return }
        if query.hasNext, !query.loading {
            query.loadNext { _, channels, _ in
                guard let channels = channels
                else { return }
                self.store(
                    channels: channels,
                    completion: completion
                )
            }
        }
    }

    open func store(
        channels: [Channel],
        completion: ((Error?) -> Void)? = nil
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            channels.forEach { channel in
                guard let message = channel.lastMessage
                else { return }
                if let group = channel as? GroupChannel,
                    group.role == nil {
                    return
                }
                ChannelMessageProvider(channelId: channel.id)
                    .markMessagesAsReceived(ids: [message.id])
            }
        }
        database.write {
            $0.createOrUpdate(channels: channels)
        } completion: { error in
            debugPrint(error as Any)
            completion?(error)
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
