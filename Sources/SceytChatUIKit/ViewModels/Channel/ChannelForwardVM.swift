//
//  ChannelForwardVM.swift
//  SceytChatUIKit
//
//  Created by Duc on 24/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import Foundation
import SceytChat

open class ChannelForwardVM: NSObject, ChannelSearchResultsUpdating {
    public required init(handler: @escaping ([ChatChannel]) -> Void) {
        self.handler = handler
        provider = Components.channelListProvider.init()
        searchService = .init(provider: provider, filter: [.chats, .groups, .channels])
        super.init()
    }
    
    public let handler: ([ChatChannel]) -> Void
    open var provider: ChannelListProvider
    private let searchService: ChannelListSearchService
    public let event = PassthroughSubject<Event, Never>()
    open lazy var searchResults: ChannelSearchResult = ChannelSearchResultImp()
    public private(set) var selectedChannels = [ChatChannel]()
    public var query: ChannelListQuery?
    private var _selectedChannel: ChatChannel?
    
    public var showCheckBox: Bool = true
    
    open lazy var channelObserver: DatabaseObserver<ChannelDTO, ChatChannel> = {
        DatabaseObserver<ChannelDTO, ChatChannel>(
            request: ChannelDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)])
                .fetch(predicate: .init(format: "unsubscribed == NO AND NOT (unsynched = YES AND lastMessage == nil)"))
                .relationshipKeyPathsFor(refreshing: [#keyPath(ChannelDTO.lastMessage.deliveryStatus),
                                                      #keyPath(ChannelDTO.lastMessage.updatedAt),
                                                      #keyPath(ChannelDTO.lastMessage.state),
//                                                      #keyPath(ChannelDTO.members.user),
                                                      #keyPath(ChannelDTO.lastReaction.messageId),
                                                      #keyPath(ChannelDTO.lastReaction.key)]),
            context: Config.database.viewContext
        ) { $0.convert() }
    }()
    
    open func onDidChangeEvent(items: DBChangeItemPaths) {
        event.send(.reload)
    }
    
    open func startDatabaseObserver() {
        channelObserver.onDidChange = { [weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        do {
            try channelObserver.startObserver()
        } catch {
            logger.errorIfNotNil(error, "observer.startObserver")
        }
    }
    
    open var numberOfChannels: Int { channelObserver.numberOfItems(in: 0) }
    
    open func channel(at indexPath: IndexPath) -> ChatChannel? {
        channelObserver.item(at: indexPath)
    }
    
    open func indexPath(for channel: ChatChannel) -> IndexPath? {
        if let row = channelObserver.items.firstIndex(of: channel) {
            return .init(row: row, section: 0)
        }
        return nil
    }
    
    open func select(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        select(channel)
    }
    
    open func select(_ channel: ChatChannel) {
        if !selectedChannels.contains(channel) {
            selectedChannels.append(channel)
            event.send(.update(channel, isSelected: true))
        } else {
            deselect(channel)
        }
    }
    
    open func deselect(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath)
        else { return }
        deselect(channel)
    }
    
    open func deselect(_ channel: ChatChannel) {
        if selectedChannels.contains(channel) {
            selectedChannels.removeAll(where: { $0.id == channel.id })
            event.send(.update(channel, isSelected: false))
        }
    }
    
    open func isSelected(_ channel: ChatChannel) -> Bool {
        selectedChannels.contains(where: { channel.id == $0.id })
    }
    
    @objc
    open func search(query: String?) {
        guard let query, !query.isEmpty else {
            searchResults = ChannelSearchResultImp()
            event.send(.reloadSearch)
            return
        }
        searchService.search(query: query) { [weak self] chats, channels in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.searchResults = ChannelSearchResultImp(chats: chats, channels: channels)
                self.event.send(.reloadSearch)
            }
        } globalBlock: { [weak self] channels in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                (self.searchResults as? ChannelSearchResultImp)?.channels = channels
                self.event.send(.reloadSearch)
            }
        } errorBlock: { error in
            logger.error("[search] error \(error)")
        }
    }
}

public extension ChannelForwardVM {
    enum Event {
        case reload, reloadSearch
        case update(ChatChannel, isSelected: Bool)
    }
}
