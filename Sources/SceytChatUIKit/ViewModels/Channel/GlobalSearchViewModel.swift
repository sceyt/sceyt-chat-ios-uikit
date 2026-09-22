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

    /// When set, channel results are restricted to direct/group channels that include this user.
    /// The text query is ignored for channel name matching while this is active.
    public var filterUser: ChatUser?

    /// Returns false when a user filter is active — the channel list section should be hidden
    /// in that case, showing only message results scoped to that user.
    public var shouldShowChannelSection: Bool { filterUser == nil }

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
        guard !channelObserver.isObserverStarted else { return }
        channelObserver.onDidChange = { [weak self] _, paths, _ in
            self?.rebuildChannels(changeItems: paths.changeItems)
        }
        channelObserver.startObserver()
    }

    open func stopDatabaseObserver() {
        channelObserver.stopObserver()
    }

    // MARK: - Browse mode

    private func rebuildChannels(changeItems: [LazyDatabaseObserver<ChannelDTO, ChatChannel>.ChangeItem] = []) {
        guard !isSearchActive, channelObserver.isObserverStarted else { return }
        var result: [ChatChannel] = []
        channelObserver.forEach { _, channel in
            result.append(channel)
            return false
        }
        // Async writeCache race: forEach may miss channels whose mapItems entry hasn't been
        // written yet (writeCache is async but onDidChange fires on a different queue).
        // Recover by merging items from the change paths that forEach skipped.
        let observerTotalCount = (0..<channelObserver.numberOfSections).reduce(0) { $0 + channelObserver.numberOfItems(in: $1) }
        if result.count < observerTotalCount {
            var resultIds = Set(result.map { $0.id })
            for changeItem in changeItems {
                switch changeItem {
                case .insert(let ip, let item), .update(let ip, let item), .move(_, let ip, let item):
                    guard !resultIds.contains(item.id) else { continue }
                    // Insert at the position the observer computed, translated to flat index.
                    var flatIndex = ip.row
                    for s in 0..<ip.section {
                        flatIndex += channelObserver.numberOfItems(in: s)
                    }
                    result.insert(item, at: min(flatIndex, result.count))
                    resultIds.insert(item.id)
                default:
                    break
                }
            }
        }
        channels = result
        DispatchQueue.main.async { [weak self] in
            self?.event = .reload
        }
    }

    // MARK: - Local search

    @objc open func search(query: String?) {
        if let filterUser = filterUser {
            isSearchActive = true
            Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let result = await fetchChannels(forMember: filterUser)
                await MainActor.run { [weak self] in
                    guard let self, isSearchActive else { return }
                    channels = result
                    event = .reloadSearch
                }
            }
            return
        }

        let trimmed = query?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmed.isEmpty else {
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

            async let directChats   = searchDirect  ? fetchDirectChats(query: trimmed)      : []
            async let groupChats    = searchGroup   ? fetchGroupChats(query: trimmed)        : []
            async let broadcastList = searchBroadcast ? fetchBroadcastChannels(query: trimmed) : []

            let direct = await directChats
            let group = await groupChats
            let chats = sort(chats: direct + group)
            let broadcasts = await broadcastList
            let merged = chats + broadcasts

            await MainActor.run { [weak self] in
                guard let self, isSearchActive else { return }
                channels = merged
                event = .reloadSearch
            }
        }
    }

    /// Returns true if `subject` contains `query` as a substring (case-insensitive).
    static func subjectMatches(subject: String, query: String) -> Bool {
        guard !query.isEmpty else { return false }
        return subject.range(of: query, options: [.caseInsensitive]) != nil
    }

    // MARK: - DB helpers

    open func fetchDirectChats(query: String) async -> [ChatChannel] {
        await withCheckedContinuation { cont in
            Components.channelListProvider.fetchChannels(query: query) { channels in
                let filtered = channels.filter { channel in
                    let peer = channel.peer
                    let name = [peer?.firstName, peer?.lastName]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    return GlobalSearchViewModel.subjectMatches(subject: name, query: query)
                }
                cont.resume(returning: filtered)
            }
        }
    }

    private func fetchGroupChats(query: String) async -> [ChatChannel] {
        await withCheckedContinuation { cont in
            SceytChatUIKit.shared.database.read { [query] context in
                let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
                request.predicate = NSPredicate(
                    format: "type = %@ AND subject CONTAINS[c] %@",
                    SceytChatUIKit.shared.config.channelTypesConfig.group, query
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
            SceytChatUIKit.shared.database.read { [query] context in
                let request = NSFetchRequest<ChannelDTO>(entityName: ChannelDTO.entityName)
                request.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.id, ascending: false)
                request.predicate = NSPredicate(
                    format: "type = %@ AND subject CONTAINS[c] %@",
                    SceytChatUIKit.shared.config.channelTypesConfig.broadcast, query
                )
                return ChannelDTO.fetch(request: request, context: context)
                    .compactMap { ChatChannel(dto: $0) }
            } completion: { result in
                cont.resume(returning: (try? result.get()) ?? [])
            }
        }
    }

    private func fetchChannels(forMember user: ChatUser) async -> [ChatChannel] {
        let userId = user.id
        let types = channelTypes.isEmpty
            ? [SceytChatUIKit.shared.config.channelTypesConfig.direct,
               SceytChatUIKit.shared.config.channelTypesConfig.group]
            : channelTypes
        return await withCheckedContinuation { cont in
            SceytChatUIKit.shared.database.read { [userId, types] context in
                let memberRequest = MemberDTO.fetchRequest()
                memberRequest.predicate = NSPredicate(format: "user.id == %@", userId)
                let memberDTOs = MemberDTO.fetch(request: memberRequest, context: context)
                let channelIds = memberDTOs.map { $0.channelId }

                guard !channelIds.isEmpty else { return [ChatChannel]() }

                let channelRequest = ChannelDTO.fetchRequest()
                channelRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "id IN %@", channelIds),
                    NSPredicate(format: "type IN %@", types),
                    NSPredicate(format: "unsubscribed == NO")
                ])
                channelRequest.sortDescriptor = NSSortDescriptor(keyPath: \ChannelDTO.sortingKey, ascending: false)
                return ChannelDTO.fetch(request: channelRequest, context: context)
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
