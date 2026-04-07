//
//  GlobalSearchViewModel.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 07.04.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import Foundation
import Combine
import CoreData
import SceytChat

open class GlobalSearchViewModel: NSObject {

    @Published public var event: Event?

    /// Filter the observer and search to only these channel types.
    /// Empty means all types. Set before calling `startDatabaseObserver()`.
    open var channelTypes: [String] = []

    @Atomic public var channels: [ChatChannel] = []

    private var isSearchActive = false

    open var fetchPredicate: NSPredicate {
        var predicates = [
            NSPredicate(format: "unsubscribed == NO"),
            NSPredicate(format: "NOT (unsynched == YES AND lastMessage == nil)")
        ]
        if !channelTypes.isEmpty {
            predicates.append(NSPredicate(format: "type IN %@", channelTypes))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    open lazy var channelObserver: LazyDatabaseObserver<ChannelDTO, ChatChannel> = {
        return LazyDatabaseObserver<ChannelDTO, ChatChannel>(
            context: SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)],
            sectionNameKeyPath: #keyPath(ChannelDTO.pinSectionIdentifier),
            fetchPredicate: fetchPredicate,
            relationshipKeyPathsObserver: [
                #keyPath(ChannelDTO.lastMessage.deliveryStatus),
                #keyPath(ChannelDTO.lastMessage.updatedAt),
                #keyPath(ChannelDTO.lastMessage.state),
                #keyPath(ChannelDTO.lastReaction.message),
                #keyPath(ChannelDTO.lastReaction.key)
            ]
        ) { $0.convert() }
    }()

    public override required init() {
        super.init()
    }

    open func startDatabaseObserver() {
        channelObserver.onDidChange = { [weak self] _, _, _ in
            self?.rebuildChannels()
        }
        channelObserver.startObserver()
    }

    // MARK: - Browse mode

    private func rebuildChannels() {
        guard !isSearchActive else { return }
        var result: [ChatChannel] = []
        channelObserver.forEach { _, channel in
            result.append(channel)
            return false
        }
        channels = result
        DispatchQueue.main.async { [weak self] in
            self?.event = .reload
        }
    }

    // MARK: - Local search

    @objc open func search(query: String?) {
        guard let query, !query.isEmpty else {
            isSearchActive = false
            rebuildChannels()
            return
        }
        isSearchActive = true
        let types = channelTypes
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let config = SceytChatUIKit.shared.config.channelTypesConfig
            let searchDirect = types.isEmpty || types.contains(config.direct)
            let searchGroup  = types.isEmpty || types.contains(config.group)
            let searchBroadcast = types.isEmpty || types.contains(config.broadcast)

            async let directChats   = searchDirect  ? fetchDirectChats(query: query)      : []
            async let groupChats    = searchGroup   ? fetchGroupChats(query: query)        : []
            async let broadcastList = searchBroadcast ? fetchBroadcastChannels(query: query) : []

            let chats = sort(chats: (await directChats) + (await groupChats))
            let broadcasts = await broadcastList
            let merged = chats + broadcasts

            await MainActor.run { [weak self] in
                guard let self, isSearchActive else { return }
                channels = merged
                event = .reloadSearch
            }
        }
    }

    // MARK: - Private DB helpers

    private func fetchDirectChats(query: String) async -> [ChatChannel] {
        await withCheckedContinuation { cont in
            Components.channelListProvider.fetchChannels(query: query) {
                cont.resume(returning: $0)
            }
        }
    }

    private func fetchGroupChats(query: String) async -> [ChatChannel] {
        await withCheckedContinuation { cont in
            SceytChatUIKit.shared.database.read { context in
                let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
                request.predicate = NSPredicate(
                    format: "type = %@ AND (subject BEGINSWITH[c] %@ OR subject CONTAINS[c] %@)",
                    SceytChatUIKit.shared.config.channelTypesConfig.group, query, " \(query)"
                )
                return ChannelDTO.fetch(request: request, context: context)
                    .compactMap { ChatChannel(dto: $0) }
            } completion: { result in
                cont.resume(returning: (try? result.get()) ?? [])
            }
        }
    }

    private func fetchBroadcastChannels(query: String) async -> [ChatChannel] {
        await withCheckedContinuation { cont in
            SceytChatUIKit.shared.database.read { context in
                let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
                request.predicate = NSPredicate(
                    format: "type = %@ AND (subject BEGINSWITH[c] %@ OR subject CONTAINS[c] %@) AND unsubscribed == NO",
                    SceytChatUIKit.shared.config.channelTypesConfig.broadcast, query, " \(query)"
                )
                return ChannelDTO.fetch(request: request, context: context)
                    .compactMap { ChatChannel(dto: $0) }
            } completion: { result in
                cont.resume(returning: (try? result.get()) ?? [])
            }
        }
    }

    private func sort(chats: [ChatChannel]) -> [ChatChannel] {
        chats.sorted {
            ($0.lastMessage?.createdAt ?? $0.createdAt) > ($1.lastMessage?.createdAt ?? $1.createdAt)
        }
    }
}

public extension GlobalSearchViewModel {
    enum Event {
        case reload
        case reloadSearch
    }
}
