//
//  ChannelListVM.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelListVM: NSObject,
                            ChatClientDelegate,
                            ChannelDelegate {
    
    private var chatClient: ChatClient {
        ChatClient.shared
    }

    @Published public var event: Event?

    public let clientDelegateIdentifier = NSUUID().uuidString
    public let channelDelegateIdentifier = NSUUID().uuidString

    public var loadNextListAfterConnect = true

    open var provider: ChannelListProvider

    open var presenceService = PresenceProvider.default

    public var isSearching = false

    public var query: ChannelListQuery?

    open lazy var channelObserver: DatabaseObserver<ChannelDTO, ChatChannel> = {
        DatabaseObserver<ChannelDTO, ChatChannel>(
            request: ChannelDTO.fetchRequest()
                .sort(descriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)])
                .fetch(predicate: .init(format: "unsubscribed == NO"))
                .relationshipKeyPathsFor(refreshing: [#keyPath(ChannelDTO.lastMessage.deliveryStatus),
                                                      #keyPath(ChannelDTO.lastMessage.updatedAt),
                                                      #keyPath(ChannelDTO.lastMessage.state),
                                                      #keyPath(ChannelDTO.peer.activityState),
                                                      #keyPath(ChannelDTO.peer.firstName),
                                                      #keyPath(ChannelDTO.peer.lastName),
                                                      #keyPath(ChannelDTO.peer.avatarUrl)]),
            context: Config.database.viewContext
        ) { $0.convert() }
    }()

    override public required init() {
        provider = ChannelListProvider()
        super.init()
        chatClient.add(delegate: self, identifier: clientDelegateIdentifier)
        chatClient.add(channelDelegate: self, identifier: channelDelegateIdentifier)
    }

    deinit {
        chatClient.removeDelegate(identifier: clientDelegateIdentifier)
    }

    open func startDatabaseObserver() {
        channelObserver.onDidChange = { [weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        do {
            try channelObserver.startObserver()
        } catch {
            debugPrint("observer.startObserver", error)
        }
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        guard !isSearching
        else {
            event = .reload
            return
        }
        event = .change(items)
        ChannelListProvider
            .totalUnreadMessagesCount { [weak self] sum in
                DispatchQueue.main.async {
                    self?.event = .unreadMessagesCount(sum)
                }
            }
    }

    open func channelProvider(_ channel: ChatChannel) -> ChannelProvider {
        ChannelProvider(channelId: channel.id)
    }

    open func channel(at indexPath: IndexPath) -> ChatChannel? {
        channelObserver.item(at: indexPath)
    }

    open func channel(id: ChannelId) -> ChatChannel? {
        channelObserver.items.first(where: { $0.id == id })
    }

    open var numberOfChannels: Int {
        channelObserver.numberOfItems(in: 0)
    }
    open func search(query: ChannelListQuery) {
        let predicate = ChannelDTO.predicate(query: query)
        do {
            try channelObserver.update(predicate: predicate)
            provider.loadChannels(query: query)
        } catch {
            debugPrint(error)
        }
    }

    open func cancelSearch() {
        guard isSearching else { return }
        query = nil
        do {
            try channelObserver.update(predicate: .init(format: "unsubscribed == NO"))
        } catch {
            debugPrint(error)
        }
        isSearching = false
    }

    open func loadChannels() {
        provider.loadChannels(query: query)
    }

    open func search(query: String) {
        isSearching = true
        self.query = ChannelListQuery
            .Builder()
            .order(.lastMessage)
            .filterKey(.subject)
            .queryType(.contains)
            .query(query)
            .build()
        search(query: self.query!)
    }

    open func delete(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath) else { return }
        channelProvider(channel).delete()
    }

    open func leave(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath) else { return }
        if channel.type.isGroup {
            channelProvider(channel).leave()
        } else {
            channelProvider(channel).delete()
        }
    }

    open func markAsRead(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath) else { return }
        channelProvider(channel).markAs(read: true)
    }

    open func markAsUnread(at indexPath: IndexPath) {
        guard let channel = channel(at: indexPath) else { return }
        channelProvider(channel).markAs(read: false)
    }

    open func reloadChannels() {
        provider.reloadChannels(query: query)
    }

    // MARK: ChatClient Delegate

    open func chatClient(
        _ chatClient: ChatClient,
        didChange state: ConnectionState,
        error: SceytError?
    ) {
        if state == .connected,
           loadNextListAfterConnect
        {
            reloadChannels()
            SyncService.sendPendingMessages()
            SyncService.sendPendingMarkers()
        }
        event = .connection(state)
    }
    
    // MARK: Channel Delegate
    open func channel(_ channel: Channel, didStartTyping member: Member) {
        guard member.id != me
        else { return }
        event = .typing(true, .init(member: member), .init(channel: channel))
        NotificationCenter.default.post(name: .init("didStartTyping"), object: (channel, member))
    }

    open func channel(_ channel: Channel, didStopTyping member: Member) {
        guard member.id != me
        else { return }
        event = .typing(false, .init(member: member), .init(channel: channel))
        NotificationCenter.default.post(name: .init("didStopTyping"), object: (channel, member))
    }
}

public extension ChannelListVM {
    enum Event {
        case change(DBChangeItemPaths)
        case reload
        case unreadMessagesCount(Int)
        case typing(Bool, ChatChannelMember, ChatChannel)
        case connection(ConnectionState)
    }
}
