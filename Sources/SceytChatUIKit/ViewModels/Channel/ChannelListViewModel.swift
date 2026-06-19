//
//  ChannelListViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat
import Combine

open class ChannelListViewModel: NSObject,
                          ChannelDelegate, ChatClientDelegate,
                          ChannelSearchResultsUpdating {
    private var chatClient: ChatClient {
        SceytChatUIKit.shared.chatClient
    }
    
    @Published public var event: Event?

    public let clientDelegateIdentifier = NSUUID().uuidString
    public let channelDelegateIdentifier = NSUUID().uuidString
    
    public var cellAppearance: ChannelListViewController.ChannelCell.Appearance = Components.channelCell.appearance
    open var provider: ChannelListProvider
    open var presenceService = Components.presenceProvider.default
    private let searchService: ChannelListSearchService
    open lazy var searchResults: ChannelSearchResult = ChannelSearchResultImp()
    
    public var query: ChannelListQuery?
    open var queryConfig: ChannelListProvider.Config = ChannelListProvider.Config.default
    
    open var fetchPredicate: NSPredicate {
        let directType = SceytChatUIKit.shared.config.channelTypesConfig.direct

        // Base predicates
        var predicates = [
            NSPredicate(format: "unsubscribed == NO"),
            NSPredicate(format: "NOT (unsynched == YES AND lastMessage == nil)"),
            // Hide direct channels until their member rows are linked,
            // so we never render a row with peer == nil ("Deleted user").
            NSPredicate(format: "type != %@ OR members.@count > 0", directType)
        ]

        // Add type predicate if config.types is not empty
        if !queryConfig.types.isEmpty {
            predicates.append(NSPredicate(format: "type IN %@", queryConfig.types))
        }

        // Combine all predicates with AND
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private var _selectedChannel: ChatChannel?
    
    @Atomic public var layoutModels = [ChatChannel: ChannelLayoutModel]()

    /// The current channels snapshot, sorted pinned-first (pinnedAt DESC), then sortingKey DESC.
    /// Rebuilt from the observer's `rawItems` on every change or reset.
    public private(set) var channels: [ChatChannel] = []

    /// O(1) lookup by channel id into `channels`.
    private var channelIndexById: [ChannelId: Int] = [:]

    open lazy var channelObserver: LazyDBObserver<ChatChannel, ChannelDTO> = makeChannelObserver()

    /// Factory for the channel observer. Override in subclasses (e.g. tests) to inject
    /// a different `NSManagedObjectContext` or an `NSFetchedResultsController` subclass.
    open func makeChannelObserver() -> LazyDBObserver<ChatChannel, ChannelDTO> {
        let request: NSFetchRequest<ChannelDTO> = ChannelDTO.fetchRequest()
        request.sortDescriptors = [
            // Pinned channels first: `pinnedAt` is non-nil only for pinned channels and in
            // SQLite NULL sorts last under DESC, so every pinned channel ranks above every
            // unpinned one regardless of activity. Within each group, order by `sortingKey`.
            NSSortDescriptor(keyPath: \ChannelDTO.pinnedAt, ascending: false),
            NSSortDescriptor(keyPath: \ChannelDTO.sortingKey, ascending: false)
        ]
        request.predicate = fetchPredicate
        return LazyDBObserver<ChatChannel, ChannelDTO>(
            context: SceytChatUIKit.shared.database.backgroundReadOnlyObservableContext,
            fetchRequest: request,
            itemCreator: { [weak self] dto in
                let channel = dto.convert()
                self?.createLayoutModel(channel: channel)
                return channel
            },
            // The delivery tick, edited-text, and last-message metadata are read from the
            // `lastMessage` relationship. A change confined to that related MessageDTO does
            // not mark the ChannelDTO as updated, so the FRC would never report the row and
            // the cell would stay stale until the next fetch (e.g. app relaunch). Tracking
            // these keypaths re-faults the channel row whenever its last message changes.
            relationshipKeyPaths: [
                #keyPath(ChannelDTO.lastMessage.deliveryStatus),
                #keyPath(ChannelDTO.lastMessage.updatedAt),
                #keyPath(ChannelDTO.lastMessage.state),
                #keyPath(ChannelDTO.lastMessage.metadata)
            ]
        )
    }
    
    override public required init() {
        provider = Components.channelListProvider.init(config: queryConfig)
        searchService = .init(provider: provider, filter: .all)
        super.init()
        SceytChatUIKit.shared.chatClient.add(delegate: self, identifier: clientDelegateIdentifier)
        SceytChatUIKit.shared.chatClient.add(channelDelegate: self, identifier: channelDelegateIdentifier)
    }
    
    public required init(cellAppearance: ChannelListViewController.ChannelCell.Appearance) {
        self.cellAppearance = cellAppearance
        provider = Components.channelListProvider.init(config: queryConfig)
        searchService = .init(provider: provider, filter: .all)
        super.init()
        SceytChatUIKit.shared.chatClient.add(delegate: self, identifier: clientDelegateIdentifier)
        SceytChatUIKit.shared.chatClient.add(channelDelegate: self, identifier: channelDelegateIdentifier)
    }
    
    deinit {
        SceytChatUIKit.shared.chatClient.removeDelegate(identifier: clientDelegateIdentifier)
        SceytChatUIKit.shared.chatClient.removeChannelDelegate(identifier: channelDelegateIdentifier)
    }
    
    open func startDatabaseObserver() {
        channelObserver.onDidChange = { [weak self] changes in
            guard let self else { return }
            // Always rebuild the local snapshot (dedup + index) before handing off,
            // so `onDidChangeEvent` subclasses see a coherent `channels` array.
            self.rebuildLocalSnapshot()
            self.onDidChangeEvent(items: DBChangeItemPaths(changeItems: changes))
        }
        channelObserver.onReset = { [weak self] in
            self?.applyReset()
        }
        do {
            try channelObserver.startObserving()
        } catch {
            logger.errorIfNotNil(error, "ChannelListViewModel failed to start observer")
        }
    }

    /// Above this many structural changes in a single cycle, emit `.reload` instead
    /// of `.change(items)` — the animated diff stops being informative and a single
    /// reload pass is cheaper.
    public static let reloadThreshold = 10

    /// Default event emitter for an observer change cycle. Override to customize how
    /// observer paths translate to `Event`. The default implementation:
    /// - Emits `.reload` if duplicate channels were dropped from the snapshot — in
    ///   that case `items`' indexes were computed against the un-deduped observer
    ///   snapshot and would be off against the local `channels` array.
    /// - Emits `.reload` if structural change count crosses `reloadThreshold`.
    /// - Otherwise emits `.change(items)`.
    /// - Kicks off an async refresh of the total unread count.
    open func onDidChangeEvent(items: Paths) {
        let removedDuplicates = channelObserver.rawItems.count > channels.count
        let changedCount = items.inserts.count + items.deletes.count + items.moves.count

        if removedDuplicates {
            logger.warn("ChannelListViewModel: observer snapshot had duplicates (raw=\(channelObserver.rawItems.count), deduped=\(channels.count)) — falling back to .reload")
            event = .reload
        } else if changedCount > Self.reloadThreshold {
            event = .reload
        } else {
            event = .change(items)
        }
        refreshTotalUnreadCount()
    }

    /// Called after the observer restarts under a new predicate. Treat as a full reload.
    open func applyReset() {
        rebuildLocalSnapshot()
        event = .reload
        refreshTotalUnreadCount()
    }

    /// Builds `channels` and `channelIndexById` from the observer's snapshot, keeping
    /// the first occurrence of each `ChannelId`. Since `rawItems` is sorted
    /// pinned-first (`pinnedAt DESC`) then `sortingKey DESC`, the first occurrence is the
    /// highest-priority (pinned and/or most recently active) row — which is the one we want to surface.
    /// This guards against transient duplicates that can appear before Core Data's
    /// uniqueness constraint on `ChannelDTO.id` collapses them on save.
    private func rebuildLocalSnapshot() {
        let items = channelObserver.rawItems
        var deduped: [ChatChannel] = []
        deduped.reserveCapacity(items.count)
        var index: [ChannelId: Int] = [:]
        index.reserveCapacity(items.count)
        var seen = Set<ChannelId>()
        seen.reserveCapacity(items.count)

        for channel in items {
            guard seen.insert(channel.id).inserted else {
                logger.warn("ChannelListViewModel dropped duplicate channel id=\(channel.id) from observer snapshot")
                continue
            }
            index[channel.id] = deduped.count
            deduped.append(channel)
        }
        channels = deduped
        channelIndexById = index
    }

    private func refreshTotalUnreadCount() {
        Components.channelListProvider
            .totalUnreadMessagesCount(types: queryConfig.types) { [weak self] sum in
                DispatchQueue.main.async {
                    self?.event = .unreadMessagesCount(sum)
                }
            }
    }
    
    open func createLayoutModel(channel: ChatChannel) {
        if let model = layoutModels[channel] {
            _ = model.update(channel: channel)
        } else {
            layoutModels[channel] = Components.channelLayoutModel.init(channel: channel, appearance: cellAppearance)
        }
    }
    
    open func channelProvider(_ channel: ChatChannel) -> ChannelProvider {
        Components.channelProvider.init(channelId: channel.id)
    }
    
    //MARK: Channel models
    open func channel(at indexPath: IndexPath) -> ChatChannel? {
        guard indexPath.section == 0, channels.indices.contains(indexPath.row) else { return nil }
        return channels[indexPath.row]
    }

    open func channel(id: ChannelId) -> ChatChannel? {
        guard let idx = channelIndexById[id], channels.indices.contains(idx) else { return nil }
        return channels[idx]
    }
    
    open func fetchChannel(id: ChannelId,
                           completion: @escaping (ChatChannel?) -> Void) {
        Components.channelProvider.init(channelId: id)
            .fetchChannel(completion: completion)
    }
    
    open func layoutModel(at indexPath: IndexPath) -> ChannelLayoutModel? {
        if let channel = channel(at: indexPath) {
            return layoutModels[channel]
        }
        return nil
    }

    open func layoutModel(id: ChannelId) -> ChannelLayoutModel? {
        if let channel = channel(id: id) {
            return layoutModels[channel]
        }
        return nil
    }
    
    open var numberOfSections: Int { 1 }

    open func numberOfChannel(at section: Int) -> Int {
        section == 0 ? channels.count : 0
    }

    //MARK: Channel search
    open func search(channelListQuery: ChannelListQuery) {
        let predicate = ChannelDTO.predicate(query: channelListQuery)
        channelObserver.restart(predicate: predicate)
        provider.loadChannels(query: channelListQuery)
    }
   
    @objc
    open func search(query: String?) {
        guard let query, !query.isEmpty else {
            searchResults = ChannelSearchResultImp()
            event = .reloadSearch
            return
        }
        searchService.search(query: query) { [weak self] chats, channels in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.searchResults = ChannelSearchResultImp(chats: chats, channels: channels)
                self.event = .reloadSearch
            }
        } globalBlock: { [weak self] channels in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                (self.searchResults as? ChannelSearchResultImp)?.channels = channels
                self.event = .reloadSearch
            }
        } errorBlock: { error in
            logger.error(" error \(error)")
        }
    }
    
    // MARK: - Channel actions
    open func delete(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        delete(channel: channel)
    }
    
    open func delete(channel: ChatChannel) {
        channelProvider(channel).delete()
    }
    
    open func leave(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        leave(channel: channel)
    }
    
    open func leave(channel: ChatChannel) {
        channelProvider(channel).leave()
    }
    
    open func hide(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        hide(channel: channel)
    }
    
    open func hide(channel: ChatChannel) {
        channelProvider(channel).hide()
    }
    
    open func markAs(read: Bool, at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        markAs(read: read, channel: channel)
    }
    
    open func markAs(read: Bool, channel: ChatChannel) {
        channelProvider(channel).markAs(read: read)
    }
    
    open func mute(_ value: TimeInterval, at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        mute(value, channel: channel)
    }
    
    open func mute(_ value: TimeInterval, channel: ChatChannel) {
        channelProvider(channel).mute(timeInterval: value)
    }
    
    open func unmute(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        unmute(channel: channel)
    }
    
    open func unmute(channel: ChatChannel) {
        channelProvider(channel).unmute()
    }
    
    open func pin(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        pin(channel: channel)
    }
    
    open func pin(channel: ChatChannel) {
        channelProvider(channel).pin()
    }
    
    open func unpin(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        unpin(channel: channel)
    }
    
    open func unpin(channel: ChatChannel) {
        channelProvider(channel).unpin()
    }
    
    open func deleteAllMessages(at indexPath: IndexPath, forEveryone: Bool) {
        guard let channel = channel(at: indexPath)
        else { return }
        deleteAllMessages(channel: channel, forEveryone: forEveryone)
    }
      
    open func deleteAllMessages(channel: ChatChannel, forEveryone: Bool) {
        channelProvider(channel).deleteAllMessages(forEveryone: forEveryone)
    }
    
    open func loadChannels() {
//        channelObserver.loadNext()
//        provider.loadChannels(query: query)
    }
    
    // MARK: ChatClient Delegate
    open func chatClient(
        _ chatClient: ChatClient,
        didChange state: ConnectionState,
        error: SceytError?
    ) {
        event = .connection(state)
    }
    
    //MARK: ChatClient delegate: Channel events
    open func channel(_ channel: Channel, didReceive channelEvent: ChannelEvent) {
        switch channelEvent.name {
        case ChannelEvent.startTyping:
            handleChannel(channel, didStartTyping: channelEvent.user)
        case ChannelEvent.stopTyping:
            handleChannel(channel, didStopTyping: channelEvent.user)
        case ChannelEvent.startRecording:
            handleChannel(channel, didStartRecording: channelEvent.user)
        case ChannelEvent.stopRecording:
            handleChannel(channel, didStopRecording: channelEvent.user)
        default:
            break
        }
    }

    //MARK: Channel typing event handlers
    open func handleChannel(_ channel: Channel, didStartTyping user: User) {
        guard user.id != SceytChatUIKit.shared.currentUserId
        else { return }
        event = .typing(true, .init(user: user), .init(channel: channel))
    }
    
    open func handleChannel(_ channel: Channel, didStopTyping user: User) {
        guard user.id != SceytChatUIKit.shared.currentUserId
        else { return }
        event = .typing(false, .init(user: user), .init(channel: channel))
    }
    
    //MARK: Channel recording event handlers
    open func handleChannel(_ channel: Channel, didStartRecording user: User) {
        guard user.id != SceytChatUIKit.shared.currentUserId
        else { return }
        event = .recording(true, .init(user: user), .init(channel: channel))
    }
    
    open func handleChannel(_ channel: Channel, didStopRecording user: User) {
        guard user.id != SceytChatUIKit.shared.currentUserId
        else { return }
        event = .recording(false, .init(user: user), .init(channel: channel))
    }
    
    //MARK: Select channel
    open func selectChannel(at indexPath: IndexPath) {
        _selectedChannel = channel(at: indexPath)
    }
    
    open func deselectChannel() {
        _selectedChannel = nil
    }
    
    open func selectedChannel() -> ChatChannel? {
        _selectedChannel
    }
    
    open func isSelected(_ channel: ChatChannel) -> Bool {
        _selectedChannel?.id == channel.id
    }
    
    public func select(_ channel: ChatChannel) {
        _selectedChannel = channel
        event = .showChannel(channel)
    }
}

public extension ChannelListViewModel {

    /// Alias for the change-paths shape the observer hands to the VC. Same as the
    /// `DBChangeItemPaths` other view models use — kept under this name so callers
    /// can refer to it as `ChannelListViewModel.Paths` (which the public API exposed
    /// historically) and the VC's `updateTableView(paths:)` signature stays
    /// self-describing.
    typealias Paths = DBChangeItemPaths

    enum Event {
        case change(Paths)
        case reload
        case reloadSearch
        case resetFingerprints
        case unreadMessagesCount(Int)
        case typing(Bool, ChatUser, ChatChannel)
        case recording(Bool, ChatUser, ChatChannel)
        case connection(ConnectionState)
        case showChannel(ChatChannel)
    }
}


extension ChannelListViewModel {
    
    func deleteDataBase(completion: (() -> Void)? = nil) {
        channelObserver.stopObserving()
        layoutModels.removeAll(keepingCapacity: true)
        channels = []
        channelIndexById = [:]
        Components.storage.deleteAll()
        DataProvider.database.deleteAll { [weak self] in
            guard let self else { return }
            do {
                try self.channelObserver.startObserving()
            } catch {
                logger.errorIfNotNil(error, "ChannelListViewModel failed to restart observer after deleteDataBase")
            }
            completion?()
            SyncService.syncChannels()
        }
    }
}
