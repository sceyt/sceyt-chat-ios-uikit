//
//  ChannelListSearchService.swift
//  SceytChatUIKit
//
//  Created by Duc on 24/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import CoreData
import SceytChat

public struct ChannelListSearchService {
    let filter: Filter
    let provider: ChannelListProvider
    
    public init(provider: ChannelListProvider = .init(), filter: Filter = .all) {
        self.provider = provider
        self.filter = filter
    }
    
    public func search(query: String,
                localBlock: @escaping ([ChatChannel], [ChatChannel]) -> Void,
                globalBlock: @escaping ([ChatChannel]) -> Void,
                errorBlock: @escaping (Error) -> Void)
    {
        Task(priority: .userInitiated) {
            do {
                let directChannel = try await searchDirectChatsBy(query: query)
                let groupChats: [ChatChannel]
                let channels: [ChatChannel]
                if filter.contains(.groups) {
                    groupChats = try await searchGroupChats(query: query)
                } else {
                    groupChats = []
                }
                
                if filter.contains(.channels) {
                    channels = try await searchChannels(query: query)
                } else {
                    channels = []
                }
                let allChats = sort(chats: directChannel + groupChats)
                localBlock(allChats, channels)
                let channelListQuery = ChannelListQuery
                    .Builder()
                    .order(.lastMessage)
                    .filterKey(.subject)
                    .search(.contains)
                    .limit(20)
                    .query(query)
                    .build()
                provider.loadChannels(query: channelListQuery) { error in
                    guard error == nil
                    else {
                        logger.debug("[search] loadChannels \(error!)")
                        return
                    }
                    Task(priority: .userInitiated) {
                        if let channels = try? await searchChannels(query: query) {
                            globalBlock(channels)
                        }
                    }
                }
            } catch {
                errorBlock(error)
            }
        }
    }
    
    private func sort(chats: [ChatChannel]) -> [ChatChannel] {
        return chats.sorted { v1, v2 in
            (v1.lastMessage?.createdAt ?? v1.createdAt) > (v2.lastMessage?.createdAt ?? v1.createdAt)
        }
    }
    
    private func searchDirectChatsBy(query: String) async throws -> [ChatChannel] {
        return try await withCheckedThrowingContinuation { continuation in
            Components.channelListProvider.fetchChannels(query: query) {
                continuation.resume(with: .success($0))
            }
        }
    }
    
    private func searchGroupChats(query: String) async throws -> [ChatChannel] {
        return try await withCheckedThrowingContinuation { continuation in
            Config.database.read { context in
                let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
                request.predicate = .init(format: "type = %@ AND (subject BEGINSWITH[c] %@ OR subject CONTAINS[c] %@)", SCTUIKitConfig.privateChannel, query, " \(query)")
                return ChannelDTO.fetch(request: request, context: context)
                    .compactMap { ChatChannel(dto: $0) }
            } completion: { result in
                continuation.resume(with: result)
            }
        }
    }
    
    private func searchChannels(query: String) async throws -> [ChatChannel] {
        let unjoined = filter.contains(.unjoinedChannels)
        let readOnly = filter.contains(.readOnlyChannels)
        return try await withCheckedThrowingContinuation { continuation in
            Config.database.read { context in
                let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
                var format = "type = %@ AND (subject BEGINSWITH[c] %@  OR subject CONTAINS[c] %@)"
                if !unjoined {
                    format += " AND unsubscribed == NO"
                }
                request.predicate = .init(format: format, SCTUIKitConfig.broadcastChannel, query, " \(query)")
                return ChannelDTO.fetch(request: request, context: context)
                    .compactMap { ChatChannel(dto: $0) }
            } completion: { result in
                if !readOnly, let channels = try? result.get() {
                    if !readOnly {
                        let newList = channels.compactMap { channel in
                            var isReadOnlyChannel: Bool {
                                channel.channelType == .broadcast &&
                                !(channel.userRole == Config.chatRoleOwner ||
                                  channel.userRole == Config.chatRoleAdmin)
                            }
                            return isReadOnlyChannel ? nil : channel
                        }
                        continuation.resume(with: .success(newList))
                    } else {
                        continuation.resume(with: .success(channels))
                    }
                    
                } else {
                    continuation.resume(with: result)
                }
            }
        }
    }
}

public extension ChannelListSearchService {
    struct Filter: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let chats = Filter(rawValue: 1 << 0)
        public static let groups = Filter(rawValue: 1 << 1)
        public static let channels = Filter(rawValue: 1 << 2)
        public static let unjoinedChannels = Filter(rawValue: 1 << 3)
        public static let readOnlyChannels = Filter(rawValue: 1 << 4)
        public static let operatorChannels = Filter(rawValue: 1 << 5)
        
        public static let all: Filter = [.chats, .groups, .channels, unjoinedChannels, .readOnlyChannels, .operatorChannels]
    }
}

public protocol ChannelSearchResult {
    var isEmpty: Bool { get }
    var numberOfSections: Int { get }
    func numberOfChannels(in section: Int) -> Int
    func channel(at indexPath: IndexPath) -> ChatChannel?
    func header(for section: Int) -> String?
}

public class ChannelSearchResultImp: ChannelSearchResult {
    public var chats: [ChatChannel]
    public var channels: [ChatChannel]
    
    public init(chats: [ChatChannel] = [],
                channels: [ChatChannel] = [])
    {
        self.chats = chats
        self.channels = channels
    }
    
    public var isEmpty: Bool {
        chats.isEmpty && channels.isEmpty
    }
    
    public var numberOfSections: Int { 2 }
    
    public func numberOfChannels(in section: Int) -> Int {
        switch section {
        case 0:
            return chats.count
        case 1:
            return channels.count
        default:
            return 0
        }
    }
    
    public func channel(at indexPath: IndexPath) -> ChatChannel? {
        switch indexPath.section {
        case 0:
            return chats[indexPath.row]
        case 1:
            return channels[indexPath.row]
        default:
            return nil
        }
    }
    
    public func header(for section: Int) -> String? {
        guard numberOfChannels(in: section) > 0
        else { return nil }
        
        switch section {
        case 0:
            return L10n.Channel.Forward.chatsGroups
        case 1:
            return L10n.Channel.Forward.channels
        default:
            return nil
        }
    }
}
