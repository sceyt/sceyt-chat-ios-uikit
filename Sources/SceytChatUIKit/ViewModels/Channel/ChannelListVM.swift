//
//  ChannelListVM.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

open class ChannelListVM: NSObject,
                          ChannelDelegate, ChatClientDelegate,
                          ChannelSearchResultsUpdating {
    private var chatClient: ChatClient {
        ChatClient.shared
    }
    
    public typealias Paths = LazyDatabaseObserver<ChannelDTO, ChatChannel>.ChangeItemPaths
    
    @Published public var event: Event?

    public let clientDelegateIdentifier = NSUUID().uuidString
    public let channelDelegateIdentifier = NSUUID().uuidString
        
    open var provider: ChannelListProvider
    open var presenceService = Components.presenceProvider.default
    private let searchService: ChannelListSearchService
    open lazy var searchResults: ChannelSearchResult = ChannelSearchResultImp()
    
    public var query: ChannelListQuery?
    public var fetchPredicate =  NSPredicate(format: "unsubscribed == NO AND NOT (unsynched = YES AND lastMessage == nil)")
    public var showCheckBox: Bool = false
    private var _selectedChannel: ChatChannel?
    
    @Atomic public private(set) var layoutModels = [ChatChannel: ChannelLayoutModel]()
      
    open lazy var channelObserver: LazyDatabaseObserver<ChannelDTO, ChatChannel> = {
        return LazyDatabaseObserver<ChannelDTO, ChatChannel>(
            context: Config.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)],
            sectionNameKeyPath: #keyPath(ChannelDTO.pinSectionIdentifier),
            fetchPredicate: fetchPredicate,
            relationshipKeyPathsObserver: [
                #keyPath(ChannelDTO.lastMessage.deliveryStatus),
                #keyPath(ChannelDTO.lastMessage.updatedAt),
                #keyPath(ChannelDTO.lastMessage.state),
//                #keyPath(ChannelDTO.members.user),
                #keyPath(ChannelDTO.lastReaction.message),
                #keyPath(ChannelDTO.lastReaction.key)
            ]
        ) { [weak self] in
            let channel = $0.convert()
            self?.createLayoutModel(channel: channel)
            return channel
        }
    }()
    
    override public required init() {
        provider = Components.channelListProvider.init()
        searchService = .init(provider: provider, filter: .all)
        super.init()
        chatClient.add(delegate: self, identifier: clientDelegateIdentifier)
        chatClient.add(channelDelegate: self, identifier: channelDelegateIdentifier)
    }
    
    deinit {
        chatClient.removeDelegate(identifier: clientDelegateIdentifier)
        chatClient.removeChannelDelegate(identifier: channelDelegateIdentifier)
    }
    
    open func startDatabaseObserver() {
        channelObserver.onDidChange = { [weak self] items, events in
            self?.onDidChangeEvent(items: items)
        }
        do {
            try channelObserver.startObserver()
        } catch {
            logger.errorIfNotNil(error, "startDatabaseObserver")
        }
    }
    open func onDidChangeEvent(items: Paths) {
        if SyncService.isSyncing || items.numberOfChangedItems > 2 {
            event = .reload
        } else {
            event = .change(items)
        }
        Components.channelListProvider
            .totalUnreadMessagesCount { [weak self] sum in
                DispatchQueue.main.async {
                    self?.event = .unreadMessagesCount(sum)
                }
            }
    }
    
    open func createLayoutModel(channel: ChatChannel) {
        if let model = layoutModels[channel] {
            _ = model.update(channel: channel)
        } else {
            layoutModels[channel] = Components.channelLayoutModel.init(channel: channel)
        }
    }
    
    open func channelProvider(_ channel: ChatChannel) -> ChannelProvider {
        Components.channelProvider.init(channelId: channel.id)
    }
    
    //MARK: Channel models
    open func channel(at indexPath: IndexPath) -> ChatChannel? {
        channelObserver.item(at: indexPath)
    }
    
    open func channel(id: ChannelId) -> ChatChannel? {
        var chatChannel: ChatChannel?
        channelObserver.forEach { _, channel in
            if channel.id == id {
                chatChannel = channel
                return true
            }
            return false
        }
        return chatChannel
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
    
    open var numberOfSections: Int {
        channelObserver.numberOfSections
    }
    
    open func numberOfChannel(at section: Int) -> Int {
        channelObserver.numberOfItems(in: section)
    }
    
    //MARK: Channel search
    open func search(channelListQuery: ChannelListQuery) {
        let predicate = ChannelDTO.predicate(query: channelListQuery)
        do {
            try channelObserver.restartObserver(fetchPredicate: predicate)
            provider.loadChannels(query: channelListQuery)
        } catch {
            logger.errorIfNotNil(error, "restartObserver")
        }
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
            logger.error("[search] error \(error)")
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
        if state == .connected,
            Config.syncChannelsAfterConnect {
            SyncService.syncChannels()
        }
        event = .connection(state)
    }
    
    //MARK: Channel typing events
    open func channel(_ channel: Channel, didStartTyping member: Member) {
        guard member.id != me
        else { return }
        event = .typing(true, .init(member: member), .init(channel: channel))
    }
    
    open func channel(_ channel: Channel, didStopTyping member: Member) {
        guard member.id != me
        else { return }
        event = .typing(false, .init(member: member), .init(channel: channel))
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

public extension ChannelListVM {
    
    enum Event {
        case change(Paths)
        case reload
        case reloadSearch
        case unreadMessagesCount(Int)
        case typing(Bool, ChatChannelMember, ChatChannel)
        case connection(ConnectionState)
        case showChannel(ChatChannel)
    }
}
