//
//  ChannelViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit
import Combine

open class ChannelViewModel: NSObject, ChatClientDelegate, ChannelDelegate {
    public typealias ChangeItem = LazyDatabaseObserver<MessageDTO, ChatMessage>.ChangeItemPaths
    //MARK: Events
    @Published public var event: Event?
    @Published public var newMessageCount: UInt64 = 0
    @Published public var peerPresence: Presence?
    
    @Published public var isEditing: Bool = false
    @Published public var isSearching: Bool = false
    @Published public var isSearchResultsLoading: Bool = false
    @Published public var selectedMessages = Set<MessageLayoutModel>()
    @Published public var searchResult: MessageSearchCoordinator!
    
    //MARK: Delegate identifier
    public let clientDelegateIdentifier = NSUUID().uuidString
    public let channelDelegateIdentifier = NSUUID().uuidString
    
    //MARK: public properties
    public private(set) var provider: ChannelMessageProvider
    public private(set) var messageSender: ChannelMessageSender
    public private(set) var channelCreator: ChannelCreator
    public private(set) var loadRangeProvider: LoadRangeProvider
    public private(set) var messageMarkerProvider: ChannelMessageMarkerProvider
    public private(set) lazy var channelProvider = Components.channelProvider
        .init(channelId: channel.id)
    
    public var chatClient: ChatClient {
        SceytChatUIKit.shared.chatClient
    }
    
    public let presenceProvider = PresenceProvider.default
    
    //MARK: Message observer
    open lazy var messageObserver: LazyMessagesObserver = {
        createMessageObserver()
    }()
    
    private func createMessageObserver() -> LazyMessagesObserver {
        LazyMessagesObserver(channelId: channel.id, loadRangeProvider: loadRangeProvider) { [weak self] in
            let message = $0.convert()
            self?.updateUnreadIndexIfNeeded(message: message)
            self?.createLayoutModel(for: message)
            return message
        }
    }
    
    //MARK: Channel observer
    open lazy var channelObserver: DatabaseObserver<ChannelDTO, ChatChannel> = {
        DatabaseObserver<ChannelDTO, ChatChannel>(
            request: ChannelDTO.fetchRequest()
                .fetch(predicate: .init(format: "id == %lld", channel.id))
                .sort(descriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)]),
            context: SceytChatUIKit.shared.database.viewContext
        ) { $0.convert() }
    }()
    
    open lazy var linkMetadataProvider = LinkMetadataProvider()
    
    open lazy var previewer = AttachmentPreviewDataSource(channel: channel)
    
    public let attachmentUploadInfo = MessageAttachmentUploadInfo.default
    open var isUnsubscribedChannel: Bool {
        guard channel.channelType == .broadcast
        else { return false }
        return channel.userRole == nil
    }
    
    open var isReadOnlyChannel: Bool {
        channel.channelType == .broadcast &&
        !(channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.owner ||
          channel.userRole == SceytChatUIKit.shared.config.memberRolesConfig.admin)
    }
    
    open var isDirectChat: Bool {
        channel.channelType == .direct
    }
    
    open var isDeletedUser: Bool {
        isDirectChat && channel.peer?.state != .active && !channel.isSelfChannel
    }
    
    public private(set) var channel: ChatChannel {
        didSet {
            markAsReadIfNeeded()
        }
    }
    
    public let threadMessage: ChatMessage?
    @Atomic public private(set) var layoutModels = [Key: MessageLayoutModel]()
    
    public private(set) var lastDisplayedMessageId: MessageId = 0
    public private(set) var selectedMessageForAction: (ChatMessage, MessageAction)?
    public static var messagesFetchLimit: UInt = 50
    open var hasUnreadMessages: Bool {
        channel.newMessageCount > 0
    }
    
    open var canUpdateUnreadPosition = true
    
    //MARK: private properties
    private var schedulers = [UserId: Scheduler]()
    private var isFetchingData = false
    private var loadLastMessagesAfterConnect = false
    private var lastLoadPrevMessageId: MessageId = 0
    private var lastLoadNextMessageId: MessageId = 0
    private var lastLoadNearMessageId: MessageId = 0
    private(set) var scrollToMessageIdIfSearching: MessageId = 0
    open private(set) var scrollToRepliedMessageId: MessageId = 0
    private(set) var searchDirection: SearchDirection = .none
    private var markMessagesQueue = DispatchQueue(label: "com.sceytchat.uikit.mark_messages")
    @Atomic private var markMessagesTaskStarted = false
    @Atomic private var lasMarkDisplayedMessageId: MessageId = 0
    @Atomic private var lastPendingMarkDisplayedMessageId: MessageId = 0
    @Atomic private var isAppActive: Bool = true
    @Atomic private var isRestartingMessageObserver: DataReloadingType = .none
    
    // MARK: internal properties
    var lastNavigatedIndexPath: IndexPath?
    
    //MARK: required init
    public required init(
        channel: ChatChannel,
        threadMessage: ChatMessage? = nil
    ) {
        
        provider = Components.channelMessageProvider.init(
            channelId: channel.id,
            threadMessageId: threadMessage?.id
        )
        provider.queryLimit = Self.messagesFetchLimit
        messageSender = Components.channelMessageSender
            .init(channelId: channel.id, threadMessageId: threadMessage?.id)
        channelCreator = Components.channelCreator.init()
        messageMarkerProvider = Components.channelMessageMarkerProvider.init(channelId: channel.id)
        loadRangeProvider = Components.loadRangeProvider.init()
        self.channel = channel
        self.threadMessage = threadMessage
        if let lastMessage = channel.lastMessage {
            if channel.lastDisplayedMessageId == lastMessage.id || !lastMessage.incoming {
                lastDisplayedMessageId = 0
            } else {
                lastDisplayedMessageId = channel.lastDisplayedMessageId
            }
        } else {
            lastDisplayedMessageId = 0
        }
        super.init()
        SceytChatUIKit.shared.chatClient.add(
            channelDelegate: self,
            identifier: channelDelegateIdentifier
        )
        SceytChatUIKit.shared.chatClient.add(
            delegate: self,
            identifier: clientDelegateIdentifier
        )
        event = .updateChannel
        newMessageCount = channel.newMessageCount
        markAsReadIfNeeded()
        subscribeToPeerPresence()
        ApplicationStateObserver()
            .didBecomeActive { [weak self] _ in
                self?.isAppActive = true
            }
            .didEnterBackground { [weak self] _ in
                self?.isAppActive = false
            }
        startDatabaseObserver {}
        if chatClient.connectionState == .connected {
            loadLastMessages()
        } else {
            loadLastMessagesAfterConnect = true
        }
        newMessageCount = channel.newMessageCount
        event = .updateChannel
        NotificationCenter.default
            .addObserver(
                self,
                selector: #selector(didUpdateLocalChannelNotification(_:)),
                name: .didUpdateLocalCreateChannelOnEventChannelCreate,
                object: nil)
        searchResult = .init(channelId: channel.id, searchFields: [])
    }
    
    //MARK: deinit
    deinit {
        logger.verbose("ChannelViewModel deinit for channel \(channel.id)")
        channelObserver.stopObserver()
        messageObserver.stopObserver()
        //        unsubscribeToPeerPresence()
        SceytChatUIKit.shared.chatClient.removeDelegate(identifier: clientDelegateIdentifier)
        SceytChatUIKit.shared.chatClient.removeChannelDelegate(identifier: channelDelegateIdentifier)
        if isTyping {
            provider.channelOperator.stopTyping()
        }
        SyncService.sendPendingMarkers()
    }
    
    open func invalidateLayout() {
        for model in layoutModels.values {
            createLayoutModel(for: model.message, force: true)
        }
    }
    
    //MARK: Database observer events
    open func startDatabaseObserver(completion: @escaping () -> Void) {
        messageObserver.onWillChange = { [weak self] cache, items in
            return self?.onWillChangeEvent(cache: cache, items: items)
        }
        messageObserver.onDidChange = { [weak self] in
            self?.onDidChangeEvent(isInitial: $0, items: $1, events: ($2 as? [Event]) ?? [])
        }
        
        channelObserver.onDidChange = { [weak self] in
            self?.onDidChangeChannelEvent(items: $0)
        }
        let initialMessageId: MessageId
        if lastDisplayedMessageId == 0 {
            initialMessageId = channel.lastMessage?.id ?? MessageId(Int64.max)
        } else {
            initialMessageId = lastDisplayedMessageId
        }
        messageObserver.startObserver(
            initialMessageId: initialMessageId,
            lastMessageId: channel.lastMessage?.id ?? 0,
            fetchLimit: Int(Self.messagesFetchLimit),
            completion: completion
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            try? self.channelObserver.startObserver()
            self.event = .updateChannel
        }
        let sections = messageObserver.numberOfSections
        if sections > 0 {
            let item: Int
            let row = messageObserver.numberOfItems(in: sections - 1)
            if row > 2 {
                item = row - 2
            } else if sections > 1 {
                let row = messageObserver.numberOfItems(in: sections - 2)
                item = max(0, row - 1)
            } else {
                return
            }
            if let id = messageObserver.item(at: .init(item: item, section: sections - 1))?.id {
                provider.loadNextMessages(after: id)
            }
        }
    }
    
    open func updateUserInfo(
        indexPath: IndexPath,
        message: ChatMessage,
        prevIndexPath: IndexPath?,
        prevMessage: ChatMessage?,
        nextIndexPath: IndexPath?,
        nextMessage: ChatMessage?) {
            guard !channel.isDirect
            else { return }
            if indexPath.item == 0 {
                if message.incoming {
                    layoutModel(for: message)?.showUserInfo(true)
                    if let nextMessage, let nextModel = layoutModel(for: nextMessage) {
                        if nextMessage.user.id == message.user.id {
                            nextModel.showUserInfo(false)
                        }
                    }
                }
                return
            }
            
            if let prevMessage, let _ = layoutModel(for: prevMessage) {
                if prevMessage.user.id != message.user.id {
                    layoutModel(for: message)?.showUserInfo(true)
                } else {
                    //                    layoutModel(for: message)?.showUserInfo(false)
                }
            }
            
            if let nextMessage, let nextModel = layoutModel(for: nextMessage) {
                if nextMessage.user.id == message.user.id {
                    nextModel.showUserInfo(false)
                }
            }
            
            if let model = layoutModel(for: message), model.isLastDisplayedMessage {
                if let nextMessage, let nextModel = layoutModel(for: nextMessage) {
                    nextModel.showUserInfo(true)
                }
            }
        }
    
    open func onWillChangeEvent(
        cache: LazyDatabaseObserver<MessageDTO, ChatMessage>.Cache,
        items: ChangeItem
    ) -> Any? {
        
        guard !items.isEmpty
        else { return nil }
        let changeItems = items.changeItems
        func cachedMessage(_ indexPath: IndexPath) -> ChatMessage? {
            messageObserver.workingCacheItem(at: indexPath)
        }
        
        func updateUserInfo(indexPath: IndexPath, message: ChatMessage) {
            let nextIndexPath = IndexPath(item: indexPath.item + 1, section: indexPath.section)
            let prevIndexPath = IndexPath(item: indexPath.item - 1, section: indexPath.section)
            
            let prevMessage = cachedMessage(prevIndexPath)
            let nextMessage = cachedMessage(nextIndexPath)
            self.updateUserInfo(
                indexPath: indexPath,
                message: message,
                prevIndexPath: prevMessage == nil ? nil : prevIndexPath,
                prevMessage: prevMessage,
                nextIndexPath: nextMessage == nil ? nil : nextIndexPath,
                nextMessage: nextMessage
            )
        }
        
        for item in changeItems.reversed() {
            switch item {
            case let .insert(indexPath, message):
                updateUserInfo(indexPath: indexPath, message: cachedMessage(indexPath) ?? message)
            case let .move(fromIndexPath, toIndexPath, _):
                if let message = cachedMessage(fromIndexPath) {
                    updateUserInfo(indexPath: fromIndexPath, message: cachedMessage(fromIndexPath) ?? message)
                }
                if let message = cachedMessage(toIndexPath) {
                    updateUserInfo(indexPath: toIndexPath, message: cachedMessage(toIndexPath) ?? message)
                }
            case .delete:
                break
            case let .update(indexPath, message):
                updateUserInfo(indexPath: indexPath, message: message)
                break
            }
        }
        
        if var max = changeItems.last?.indexPath, max.item > 0 {
            max.item += 1
            if let message = cachedMessage(max) {
                updateUserInfo(indexPath: max, message: message)
            }
        }
        return makeEvents(cache: cache, items: items)
    }
    
    private func makeEvents(cache: LazyDatabaseObserver<MessageDTO, ChatMessage>.Cache,
                            items: ChangeItem)
    -> [Event] {
        var events = [Event]()
        @discardableResult
        func updateLayoutModel(at indexPath: IndexPath) -> Bool {
            var isUpdated = false
            if let message = messageObserver.workingCacheItem(at: indexPath),
               let model = layoutModel(for: message) {
                var updateOptions = model.updateOptions
                if updateOptions.contains(.deliveryStatus) {
                    updateOptions.remove(.deliveryStatus)
                    if !model.message.incoming {
                        events.append(.updateDeliveryStatus(model: model, indexPath: indexPath))
                    }
                }
                isUpdated = updateOptions.rawValue != 0
            }
            
            return isUpdated
        }
        
        var paths = CollectionUpdateIndexPaths(
            inserts: items.inserts,
            reloads: items.updates,
            deletes: items.deletes,
            moves: items.moves,
            sectionInserts: items.sectionInserts,
            sectionDeletes: items.sectionDeletes
        )
        var lastIndexPath: IndexPath?
        let nm = cache.count
        if nm > 0 {
            var ip = IndexPath(item: (cache.last?.count ?? 0) - 1, section: nm - 1)
            //except prev last
            if ip.item > 0 {
                ip.item -= 1
            } else if ip.section > 0 {
                ip.section -= 1
                ip.item = (cache[safe: ip.section]?.count ?? 0) - 1
            }
            lastIndexPath = ip
        }
        
        var union = [IndexPath: Bool]()
        items.inserts.forEach { indexPath in
            union[indexPath] = true
            if indexPath == .zero {
                paths.continuesOptions.insert(.top)
            } else if let lastIndexPath,
                      indexPath > lastIndexPath {
                paths.continuesOptions.insert(.bottom)
            }
            else if let lastNavigatedIndexPath,
                    indexPath > lastNavigatedIndexPath {
                paths.continuesOptions.insert(.bottom)
            }
            else {
                paths.continuesOptions.insert(.middle)
            }
            updateLayoutModel(at: indexPath)
        }
        items.updates.forEach { indexPath in
            union[indexPath] = true
            if !updateLayoutModel(at: indexPath) {
                paths.reloads.removeAll(where: { $0 == indexPath })
            }
        }
        items.deletes.forEach { indexPath in
            union[indexPath] = true
            updateLayoutModel(at: indexPath)
        }
        items.moves.forEach { fromIndexPath, toIndexPath in
            union[fromIndexPath] = true
            union[toIndexPath] = true
            updateLayoutModel(at: fromIndexPath)
            updateLayoutModel(at: toIndexPath)
        }
        var indexPaths = union.keys.sorted()
        if !indexPaths.isEmpty {
            let last = indexPaths.last!
            indexPaths.append(.init(item: last.item + 1, section: last.section))
            for indexPath in indexPaths.reversed() {
                if let message = messageObserver.workingCacheItem(at: indexPath),
                   let model = layoutModel(for: message) {
                    var prevModel: MessageLayoutModel?
                    let prevIndexPath = findPrevIndexPath(current: indexPath, cache: cache)
                    if let prevIndexPath,
                       let prevMessage = messageObserver.workingCacheItem(at: prevIndexPath) {
                        prevModel = layoutModel(for: prevMessage)
                    }
                    updateMessageContentInsets(
                        for: model,
                        at: indexPath,
                        prevModel: prevModel,
                        prevIndexPath: prevIndexPath
                    )
                }
            }
        }
        
        guard !paths.isEmpty else { return events }
        
        func indexPathOfLastDisplayedMessageId() -> IndexPath? {
            if lastDisplayedMessageId != 0,
               canUpdateUnreadPosition {
                for (section, items) in cache.enumerated().reversed() {
                    for (row, item) in items.enumerated().reversed() {
                        if item.id == lastDisplayedMessageId {
                            return IndexPath(item: row, section: section)
                        }
                    }
                }
            }
            return nil
        }
        
        if let indexPath = indexPathOfLastDisplayedMessageId() {
            events.append(.didSetUnreadIndexPath(indexPath: indexPath))
        }
        if let max = items.inserts.max() {
            let reloadIndexPathBeforeUpdate = IndexPath(item: 0, section: 0)
            let reloadIndexPathAfterUpdate = IndexPath(item: max.item + 1, section: max.section)
            if let count = cache[safe: max.section]?.count,
               count > reloadIndexPathAfterUpdate.item,
               !paths.reloads.contains(reloadIndexPathBeforeUpdate) {
                paths.reloads.append(reloadIndexPathBeforeUpdate)
                
            }
        }
        events.append(.update(paths: paths))
        
        return events
    }
    
    open func needsToScrollAtIndexPath(
        items: ChangeItem
    ) -> (IndexPath, MessageId)? {
        
        func indexPath(
            of messageId: MessageId,
            items: ChangeItem
        ) -> IndexPath? {
            guard messageId != 0 else { return nil }
            let indexPath = items.changeItems
                .first(where: { $0.item?.id ==  messageId })?
                .indexPath
            if let indexPath {
                return indexPath
            } else {
                let indexPath = messageObserver.indexPath { $0.id == messageId }
                return indexPath
            }
        }
        
        if self.isSearching,
           let indexPath = indexPath(of: scrollToMessageIdIfSearching, items: items) {
            return (indexPath, scrollToMessageIdIfSearching)
        } else if let indexPath = indexPath(of: scrollToRepliedMessageId, items: items) {
            return (indexPath, scrollToRepliedMessageId)
        }
        return nil
    }
    
    private func updateStateAfterChangeEvent(for indexPath: IndexPath?) {
        if isSearching {
            if let indexPath {
                updateLastNavigatedIndexPath(indexPath: indexPath)
            }
            scrollToMessageIdIfSearching = 0
            searchDirection = .none
            isSearchResultsLoading = false
            isRestartingMessageObserver = .none
        } else {
            if let indexPath {
                updateLastNavigatedIndexPath(indexPath: indexPath)
            }
            resetStateAfterChangeEvent()
        }
    }
    
    private func resetStateAfterChangeEvent() {
        DispatchQueue.main
            .asyncAfter(deadline: .now() + 1) {[weak self] in
                guard let self else { return }
                self.scrollToRepliedMessageId = 0
                self.isRestartingMessageObserver = .none
            }
    }
    
    open func scrollToItemIfNeeded(items: ChangeItem) {
        
        if let (indexPath, mid) = needsToScrollAtIndexPath(items: items) {
            updateStateAfterChangeEvent(for: indexPath)
            if isSearching {
                updateLastNavigatedIndexPath(indexPath: indexPath)
                scrollToMessageIdIfSearching = 0
                searchDirection = .none
                isSearchResultsLoading = false
                isRestartingMessageObserver = .none
            } else {
                isRestartingMessageObserver = .none
            }
            scroll(to: indexPath, messageId: mid)
        }
    }
    
    open func onDidChangeEvent(
        isInitial: Bool,
        items: ChangeItem,
        events: [Event]) {
            var needToScroll = true
            defer {
                if needToScroll {
                    scrollToItemIfNeeded(items: items)
                }
            }
            if isInitial {
                let messageId = scrollToRepliedMessageId != 0 ? scrollToRepliedMessageId : lastDisplayedMessageId
                if messageId != 0,
                   let indexPath = items.changeItems
                    .first(where: {$0.item?.id == messageId})?
                    .indexPath {
                    needToScroll = false
                    event = .reloadDataAndScroll(indexPath: indexPath, animated: scrollToRepliedMessageId != 0, pos: .centeredVertically)
                    resetStateAfterChangeEvent()
                } else {
                    if let (indexPath, messageId) = needsToScrollAtIndexPath(items: items) {
                        switch searchDirection {
                        case .next:
                            event = .reloadDataAndScroll(indexPath: indexPath, animated: false, pos: .top)
                        case .prev:
                            event = .reloadDataAndScroll(indexPath: indexPath, animated: false, pos: .bottom)
                        case .none:
                            break
                        }
                        event = .scrollAndSelect(indexPath: indexPath, messageId: messageId)
                        resetStateAfterChangeEvent()
                        needToScroll = false
                    } else {
                        event = .reloadDataAndScrollToBottom
                    }
                }
                return
            }
            if numberOfSections == 0 {
                event = .showNoMessage
            }
            
            switch isRestartingMessageObserver {
            case .none:
                break
            case .reload:
                event = .reloadData
                return
            case .reloadToLatestState:
                event = .reloadDataAndScrollToBottom
                return
            case .reloadAndSelect:
                if let (indexPath, mid) = needsToScrollAtIndexPath(items: items) {
                    needToScroll = false
                    event = .reloadDataAndSelect(indexPath: indexPath, messageId: mid)
                    updateStateAfterChangeEvent(for: indexPath)
                } else {
                    event = .reloadData
                }
                return
            }
            
            if isAppActive {
                events.forEach {
                    event = $0
                }
            } else {
                let unread = events.filter {
                    switch $0 {
                    case .didSetUnreadIndexPath:
                        return true
                    default:
                        return false
                    }
                }.first
                if case .didSetUnreadIndexPath(let indexPath) = unread {
                    event = .reloadDataAndScroll(indexPath: indexPath, animated: false, pos: .top)
                    return
                }
                if let max = items.inserts.max(),
                   messageObserver.numberOfSections - 1 == max.section,
                   messageObserver.numberOfItems(in: max.section) - 1 == max.item {
                    event = .reloadDataAndScrollToBottom
                } else {
                    event = .reloadData
                }
            }
        }
    
    open func onDidChangeChannelEvent(items: DBChangeItemPaths) {
        let channels: [ChatChannel]? = items.items()
        guard let ch = channels?.first(where: { $0.id == channel.id })
        else { return }
        if !channel.unSynched,
           channel.userRole != nil,
           ch.userRole == nil {
            event = .close
        }
        if newMessageCount != ch.newMessageCount {
            newMessageCount = ch.newMessageCount
        }
        if isUpdateForView(channel: ch) {
            channel = ch
            event = .updateChannel
        } else {
            channel = ch
        }
    }
    
    open func updateMessageContentInsets(
        for model: MessageLayoutModel,
        at indexPath: IndexPath,
        prevModel: MessageLayoutModel?,
        prevIndexPath: IndexPath?) {
            var contentInsets: UIEdgeInsets = .zero
            if indexPath.item > 0,
               let prevModel {
                if model.message.incoming == prevModel.message.incoming {
                    contentInsets.top = 2
                } else {
                    contentInsets.top = 6
                }
            } else if indexPath.item == 0 {
                contentInsets.top = 2
            }
            model.contentInsets = contentInsets
        }
    
    //MARK: Models
    open var numberOfSections: Int {
        messageObserver.numberOfSections
    }
    
    open func numberOfMessages(in section: Int) -> Int {
        messageObserver.numberOfItems(in: section)
    }
    
    open func isLastMessage(at indexPath: IndexPath) -> Bool {
        messageObserver.item(at: indexPath)?.id == channel.lastMessage?.id
    }
    
    @discardableResult
    open func createLayoutModels(at indexPaths: [IndexPath]) -> [MessageLayoutModel] {
        var models = [MessageLayoutModel]()
        for indexPath in indexPaths {
            guard let message = message(at: indexPath),
                  layoutModels[.init(message: message)] == nil
            else { continue }
            let model = createLayoutModel(for: message)
            models.append(model)
            layoutModels[.init(message: message)] = model
        }
        return models
    }
    
    @discardableResult
    open func createLayoutModel(for message: ChatMessage, force: Bool = false) -> MessageLayoutModel {
        if let model = layoutModels[.init(message: message)] {
            model.update(channel: channel, message: message, force: force)
            updateLinkPreviewsForLayoutModelIfNeeded(model: model)
            return model
        }
        let model = Components.messageLayoutModel
            .init(
                channel: channel,
                message: message,
                lastDisplayedMessageId: lastDisplayedMessageId,
                appearance: MessageCell.appearance)
        layoutModels[.init(message: message)] = model
        updateLinkPreviewsForLayoutModelIfNeeded(model: model)
        return model
    }
    
    open func canSelectMessage(at indexPath: IndexPath) -> Bool {
        if isEditing, let message = message(at: indexPath), message.state != .deleted {
            return true
        }
        return false
    }
    
    open func message(at indexPath: IndexPath) -> ChatMessage? {
        if let message = messageObserver.item(at: indexPath) {
            return message
        }
        if let message = messageObserver.itemFromPrevCache(at: indexPath) {
            return message
        }
        return nil
    }
    
    open func indexPaths(for messages: [ChatMessage]) -> [MessageId: IndexPath] {
        var indexPaths = [MessageId: IndexPath]()
        var group = [Int64: ChatMessage]()
        for message in messages {
            let id = message.id == 0 ? message.tid : Int64(message.id)
            group[id] = message
        }
        messageObserver.forEach { ip, message in
            let id = message.id == 0 ? message.tid : Int64(message.id)
            if let m = group[id] {
                indexPaths[m.id] = ip
                group[id] = nil
            }
            return group.isEmpty
        }
        return indexPaths
    }
    
    open func layoutModel(at indexPath: IndexPath) -> MessageLayoutModel? {
        guard let message = message(at: indexPath)
        else { return nil }
        return layoutModel(for: message)
    }
    
    open func layoutModel(for message: ChatMessage) -> MessageLayoutModel? {
        if let model = layoutModels[.init(message: message)] {
            return model
        }
        return nil
    }
    
    open func layoutModel(for messageId: MessageId) -> MessageLayoutModel? {
        if let model = layoutModels[.init(messageId: messageId)] {
            return model
        }
        return nil
    }
    
    //MARK: Unread message index updater
    open func updateUnreadIndexIfNeeded(message: ChatMessage) {
        guard !isAppActive,
              lastDisplayedMessageId == 0
        else { return }
        let section = messageObserver.numberOfSections - 1
        let row = messageObserver.numberOfItems(in: section) - 1
        var lastMessage: ChatMessage?
        if section >= 0, row >= 0 {
            let indexPath = IndexPath(item: row, section: section)
            lastMessage = messageObserver.item(at: indexPath)
        }
        guard let lastMessage,
              message.id > lastMessage.id,
              message.incoming
        else { return }
        
        lastDisplayedMessageId = lastMessage.id
        
        let model = Components.messageLayoutModel
            .init(
                channel: channel,
                message: lastMessage,
                lastDisplayedMessageId: lastDisplayedMessageId,
                appearance: MessageCell.appearance)
        
        layoutModels[.init(message: lastMessage)] = model
    }
    
    //MARK: Typing
    
    open var isTyping = false {
        didSet { isTyping ? provider.channelOperator.startTyping() : provider.channelOperator.stopTyping() }
    }
    
    //MARK: load messages
    
    open func calculateMessageFetchOffset(
        messageId: MessageId = 0,
        fetchLimit: UInt = ChannelViewModel.messagesFetchLimit) -> Int {
            var fetchOffset: Int
            if messageId == 0 {
                fetchOffset = messageObserver.totalCountOfItems() - Int(fetchLimit)
            } else {
                let beforePredicate = messageObserver.defaultFetchPredicate
                    .and(predicate: .init(format: "id < %lld", messageId))
                let beforeCount = messageObserver.totalCountOfItems(predicate: beforePredicate)
                fetchOffset = beforeCount
                let afterCount = messageObserver
                    .totalCountOfItems(predicate: messageObserver.defaultFetchPredicate) - fetchOffset
                if  afterCount < fetchLimit {
                    fetchOffset -= Int(fetchLimit) - afterCount
                }
            }
            return max(fetchOffset, 0)
        }
    
    open func loadLastMessages() {
        if isUnsubscribedChannel {
            loadPrevMessages(before: MessageId(Int64.max))
        } else {
            if isThread || channel.lastMessage?.incoming == false || lastDisplayedMessageId == 0 {
                logger.info("ChannelViewModel loadLastMessages (prev) channel id: \(channel.id), lastMessage id \(channel.lastMessage?.id as Any)")
                provider.loadPrevMessages(before: channel.lastMessage?.id ?? MessageId(Int64.max))
            } else {
                logger.info("ChannelViewModel loadLastMessages (near) channel id: \(channel.id), lastDisplayedMessageId \(lastDisplayedMessageId)")
                provider.loadNearMessages(near: lastDisplayedMessageId)
            }
        }
    }
    
    open func loadPrevMessages(
        beforeMessageAt indexPath: IndexPath
    ) {
        guard let message = message(at: indexPath)
        else { return }
        loadPrevMessages(before: message.id)
    }
    
    open func loadNextMessages(
        afterMessageAt indexPath: IndexPath
    ) {
        guard let message = message(at: indexPath)
        else { return }
        logger.info("ChannelViewModel loadLastMessages (next) channel id: \(channel.id), \(indexPath) lastDisplayedMessageId \(message.id) \(message.body)")
        if message.id == 0 {
            loadPrevMessages(before: MessageId(Int64.max))
        } else {
            loadNextMessages(after: message.id)
        }
    }
    
    open func loadPrevMessages(
        before messageId: MessageId
    ) {
        guard !isFetchingData,
              ((lastLoadPrevMessageId != messageId && messageId != 0) || messageId == 0)
        else { return }
        lastLoadPrevMessageId = messageId
        isFetchingData = true
        DispatchQueue.main
            .asyncAfter(deadline: .now() + 1)
        {[weak self] in
            self?.resetFetchState()
        }
        func fetchPrev() {
            messageObserver.updatePredicateForPrevMessages(currentMessageId: messageId) {[weak self] result in
                guard let self else { return }
                if result {
                    messageObserver.loadPrev(before: messageId)
                }
            }
        }
        fetchPrev()
        
        provider.loadPrevMessages(
            before: messageId
        ) { [weak self] error in
            fetchPrev()
            self?.resetFetchState()
            logger.errorIfNotNil(error, "on loadPrevMessages")
        }
    }
    
    open func loadNextMessages(
        after messageId: MessageId
    ) {
        guard !isFetchingData,
              lastLoadNextMessageId != messageId
        else { return }
        lastLoadNextMessageId = messageId
        isFetchingData = true
        DispatchQueue.main
            .asyncAfter(deadline: .now() + 1)
        {[weak self] in
            self?.resetFetchState()
        }
        func fetchNext() {
            messageObserver.updatePredicateForNextMessages(currentMessageId: messageId) {[weak self] result in
                guard let self else { return }
                if result {
                    messageObserver.loadNext(after: messageId)
                }
            }
        }
        fetchNext()
        
        provider.loadNextMessages(
            after: messageId
        ) { [weak self] error in
            fetchNext()
            self?.resetFetchState()
            logger.errorIfNotNil(error, "on loadPrevMessages")
        }
        
    }
    
    open func fetchNearMessages(at indexPath: IndexPath) {
        guard let message = message(at: indexPath) else { return }
        fetchNearMessages(at: message.id)
    }
    
    open func fetchNearMessages(at messageId: MessageId) {
        guard !isFetchingData,
              lastLoadNearMessageId != messageId
        else { return }
        lastLoadNearMessageId = messageId
        isFetchingData = true
        messageObserver.loadNear(at: messageId) { [weak self] _ in
            self?.isFetchingData = false
            
        }
    }
    
    open func loadNearMessages(
        messageId: MessageId
    ) {
        provider.loadNearMessages(
            query: provider.makeQuery(),
            near: messageId
        )
    }
    
    open func loadNearMessagesOfSearchMessage(
        id: MessageId,
        completion: ((Error?) -> Void)? = nil
    ) {
        if chatClient.connectionState == .connected {
            provider.loadNearMessages(near: id) { [weak self] error in
                if error == nil {
                    self?.messageObserver.restartToNear(at: id)
                }
                completion?(error)
            }
        } else {
            completion?(SceytChatError.notConnect)
        }
    }
    
    open func loadNearMessagesOfRepliedMessage(
        id: MessageId,
        completion: ((Error?) -> Void)? = nil
    ) {
        if chatClient.connectionState == .connected {
            provider.loadNearMessages(near: id) { [weak self] error in
                if error == nil {
                    self?.messageObserver.restartToNear(at: id)
                }
                completion?(error)
            }
        } else {
            completion?(SceytChatError.notConnect)
        }
        
    }
    
    open func resetToInitialStateIfNeeded() -> Bool {
        guard let lastMessage = channel.lastMessage
        else { return false}
        if messageObserver.lastItem?.id == lastMessage.id {
            return false
        }
        let initialMessageId: MessageId
        if lastDisplayedMessageId == 0 {
            initialMessageId = lastMessage.id
        } else {
            initialMessageId = lastDisplayedMessageId
        }
        isRestartingMessageObserver = .reloadToLatestState
        let offset = calculateMessageFetchOffset(messageId: initialMessageId)
        messageObserver
            .restartObserver(fetchPredicate: messageObserver.defaultFetchPredicate,
                             offset: offset)
        { [weak self] in
            self?.isRestartingMessageObserver = .none
        }
        refreshChannel()
        return true
    }
    
    open func resetScrollState() {
        scrollToMessageIdIfSearching = 0
        scrollToRepliedMessageId = 0
        searchDirection = .none
    }
    
    private func resetFetchState() {
        lastLoadPrevMessageId = 0
        isFetchingData = false
    }
    
    open func updateLastNavigatedIndexPath(indexPath: IndexPath?) {
        lastNavigatedIndexPath = indexPath
    }
    
    //MARK: mark messages
    
    
    open func markMessage(as marker: DefaultMarker, indexPaths: [IndexPath]) {
        let messages = indexPaths.compactMap {
            message(at: $0)
        }
        
        if marker == .displayed {
            markMessageAsDisplayed(messages)
        } else {
            markMessages(messages, as: marker)
        }
    }
    
    open func markMessages( _ messages: [ChatMessage], as marker: DefaultMarker) {
        guard !markMessagesTaskStarted,
                !messages.isEmpty
        else { return }
        
        markMessagesTaskStarted = true
        
        markMessagesQueue.async { [weak self] in
            guard let self else { return }
            let filteredMessages = messages.filter {
                return !$0.incoming ? false :
                $0.userMarkers?.contains(where: { $0.user?.id == me && $0.name == marker.rawValue } ) == true ? false : true
            }
            guard !filteredMessages.isEmpty,
                    let max = filteredMessages.max(by: { $0.id < $1.id }),
                    let min = filteredMessages.min(by: { $0.id < $1.id })
            else {
                markMessagesTaskStarted = false
                return
            }
                        //
            self.messageMarkerProvider.markIfNeeded(
                after: min.id,
                before: max.id,
                markerName: marker.rawValue)
            {[weak self] error in
                self?.markMessagesTaskStarted = false
            }
        }
    }
    
    open func markMessageAsDisplayed(_ messages: [ChatMessage]) {return;
        guard !markMessagesTaskStarted,
                !messages.isEmpty
        else { return }
        
        markMessagesQueue.async { [weak self] in
            guard let self
            else { return }
            
            let message = messages.filter {
                return !$0.incoming ? false :
                $0.userMarkers?.contains(where: { $0.user?.id == me && $0.name == DefaultMarker.displayed.rawValue } ) == true ? false : true
            }.max(by: { $0.id < $1.id })
            
            guard let message, self.lasMarkDisplayedMessageId != message.id
            else {
                markMessagesTaskStarted = false
                return
            }
            let prevLasMarkDisplayedMessageId = self.lasMarkDisplayedMessageId
            self.lasMarkDisplayedMessageId = message.id
            
            self.messageMarkerProvider.markIfNeeded(
                after: prevLasMarkDisplayedMessageId,
                before: message.id,
                markerName: DefaultMarker.displayed.rawValue)
            {[weak self] error in
                self?.markMessagesTaskStarted = false
            }
        }
    }

    open func markChannelAs(read: Bool) {
        guard channel.unread == read
        else { return }
        channelProvider
            .markAs(read: read)
    }
    
    open func markChannelAsDisplayed() {
        channelProvider
            .markAs(read: true)
        if let id = channel.lastMessage?.id {
            provider.markMessagesAsDisplayed(ids: [id])
        }
    }
    
    //MARK: Send message
    open func createAndSendUserMessage(_ userMessage: UserSendMessage) {
        if isTyping {
            isTyping = false
        }
        scrollToRepliedMessageId = 0
        scrollToMessageIdIfSearching = 0
        if let lastCacheItem = messageObserver.lastItem,
            let lastMessageItem = channel.lastMessage,
            lastCacheItem.id != lastMessageItem.id {
            let offset = messageObserver.calculateMessageFetchOffset()
            messageObserver.restartObserver(fetchPredicate: messageObserver.defaultFetchPredicate, offset: offset)
        } else {
            messageObserver.update(predicate: messageObserver.defaultFetchPredicate)
        }
        
        if case let .edit(message) = userMessage.action,
           message.body == userMessage.text {
            if let oldBodyAttributes = message.bodyAttributes,
               let newBodyAttributes = userMessage.bodyAttributes {
                if oldBodyAttributes == newBodyAttributes {
                    return
                }
            } else {
                return
            }
        }
        let builder = Message
            .Builder()
            .type(userMessage.type)
        var editAttachments = [Attachment]()
        switch userMessage.action {
        case let .edit(message):
            builder.id(message.id)
            builder.tid(Int(message.tid))
            userMessage.attachments?.removeAll()
            if let attachments = message.attachments?.filter({ $0.type != "link" }) {
                editAttachments += attachments.map { $0.builder.build() }
            }
            
        case let .reply(message):
            builder.parentMessageId(message.id)
        default:
            break
        }
        
        if isThread {
            builder.parentMessageId(threadMessage!.id)
            builder.replyInThread(true)
        }
        
        if let metadata = userMessage.metadata {
            builder.metadata(metadata)
        }
        
        if let mentionUsers = userMessage.mentionUsers {
            builder.mentionUserIds(mentionUsers.map { $0.id })
        }
        
        var messages = [Message]()
        var linkAttachment = [Attachment]()
        if let attachment = userMessage.linkAttachments.first?.attachment {
            linkAttachment = [attachment]
        }
        
        if let bodyAttributes = userMessage.bodyAttributes {
            builder.bodyAttributes(bodyAttributes.map { .init(offset: $0.offset, length: $0.length, type: $0.type.rawValue, metadata: $0.metadata) })
        }
        
        if let items = userMessage.attachments, items.count > 0 {
            for (index, item) in items.enumerated() {
                if index == 0 {
                    builder.body(userMessage.text)
                } else {
                    builder.body("")
                }
                builder.attachments([item.attachment] + linkAttachment)
                messages.append(builder.build())
            }
        } else {
            builder.body(userMessage.text)
            builder.attachments(linkAttachment + editAttachments)
            messages.append(builder.build())
        }
        guard !messages.isEmpty else { return }
        
        let first = messages.remove(at: 0)
        sendUserMessage(first, action: userMessage.action)
        if let linkMetadata = userMessage.linkMetadata {
            let chatMessage = ChatMessage(message: first, channelId: channel.id)
            provider.storeLinkMetadata(linkMetadata, to: chatMessage)
        }
        for index in 0 ..< messages.count {
            DispatchQueue
                .global(qos: .userInteractive)
                .asyncAfter(deadline: .now() + TimeInterval(1 * index)) {
                    self.sendUserMessage(messages[index], action: userMessage.action)
                }
        }
    }
    
    open func sendUserMessage(
        _ message: Message,
        action: UserSendMessage.Action
    ) {
        
        @Sendable func send() {
            logger.verbose("[MESSAGE SEND] sendUserMessage messageSender \(message.body)")
            switch action {
            case .send, .reply, .forward:
                messageSender.sendMessage(message, storeBeforeSend: false) {[weak self] _ in
                    guard let self else { return }
                    if case .reload = isRestartingMessageObserver {
                        isRestartingMessageObserver = .none
                    }
                }
            case .edit:
                messageSender.editMessage(message, storeBeforeSend: false) {[weak self] _ in
                    guard let self else { return }
                    if case .reload = isRestartingMessageObserver {
                        isRestartingMessageObserver = .none
                    }
                }
            }
        }
        
        if channel.unSynched {
            provider.storePending(message: message) { _ in
                Task {
                    do {
                        if let channel = try await self.channelCreator.createChannelOnServerIfNeeded(channelId: self.channel.id) {
                            self.updateLocalChannel(channel) {
                                send()
                            }
                        } else {
                            send()
                        }
                    } catch {
                        
                    }
                }
            }
        } else {
            provider.storePending(message: message) { _ in
                send()
            }
        }
    }
    
    open func share(
        message: ChatMessage,
        to channelIds: [ChannelId],
        forward: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard !channelIds.isEmpty else {
            completion?()
            return
        }
        let builder = message.builder
        builder.id(0)
        builder.tid(0)
        builder.parentMessageId(0)
        if forward {
            builder.forwardingMessageId(message.id)
        }
        let group = DispatchGroup()
        for channelId in channelIds {
            group.enter()
            let forwardedMessage = builder.build()
            Components.channelMessageSender
                .init(channelId: channelId)
                .sendMessage(forwardedMessage) { _ in
                    group.leave()
                }
        }
        group.notify(queue: .main) {
            completion?()
        }
    }
    
    open func share(
        messages: [ChatMessage],
        to channelIds: [ChannelId],
        completion: (() -> Void)? = nil
    ) {
        guard !channelIds.isEmpty else {
            completion?()
            return
        }
        let group = DispatchGroup()
        messages.forEach {
            group.enter()
            share(message: $0, to: channelIds, forward: $0.incoming) {
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion?()
        }
    }
    
    open func deleteMessage(
        layoutModel: MessageLayoutModel,
        type: DeleteMessageType
    ) {
        layoutModel.message.attachments?.forEach {
            AttachmentTransfer.default.taskFor(message: layoutModel.message, attachment: $0)?.cancel()
        }
        if layoutModel.message.deliveryStatus == .pending {
            provider.deletePending(message: layoutModel.message.tid)
        } else {
            messageSender.deleteMessage(id: layoutModel.message.id, type: type)
        }
    }
    
    open func deleteSelectedMessages(type: DeleteMessageType) {
        selectedMessages.forEach {
            deleteMessage(layoutModel: $0, type: type)
        }
    }
    
    open func deleteAllMessages(
        forMeOnly: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        channelProvider.deleteAllMessages(
            forEveryone: !forMeOnly,
            completion: completion
        )
    }
    
    open func addReaction(
        layoutModel: MessageLayoutModel,
        key: String, score: UInt16 = 1
    ) {
        if selectedEmojis(identifier: .init(value: layoutModel)).contains(key) {
            return
        }
        provider.addReactionToMessage(id: layoutModel.message.id, key: key, score: score)
    }
    
    open func canDeleteReaction(
        message: ChatMessage,
        key: String
    ) -> Bool {
        return message.userReactions?.contains(where: { $0.key == key }) == true
    }
    
    open func deleteReaction(
        layoutModel: MessageLayoutModel,
        key: String
    ) {
        provider.deleteReactionFromMessage(
            message: layoutModel.message,
            key: key
        )
    }
    open func report(layoutModel: MessageLayoutModel) {
        // TODO: Report Message
        logger.debug("Report Message")
    }
    
    open func updateDraftMessage(_ message: NSAttributedString?) {
        let text = message == nil || message?.isEmpty == true ? nil : message
        let date = text == nil ? nil : Date()
        channelProvider.saveDraftMessage(text, at: date)
    }
    
    open func stopFileTransfer(message: ChatMessage, attachment: ChatMessage.Attachment) {
        fileProvider.stopTransfer(message: message, attachment: attachment)
    }
    
    open func resumeFileTransfer(message: ChatMessage, attachment: ChatMessage.Attachment) {
        fileProvider.resumeTransfer(message: message, attachment: attachment) {[weak self] status in
            if let self, !status {
                if message.deliveryStatus == .pending, attachment.filePath != nil {
                    attachment.status = .pending
                    self.messageSender.resendMessage(message)
                } else if attachment.url != nil {
                    attachment.status = .pending
                    fileProvider.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment])
                }
            }
        }
    }
    
    open func downloadMessageAttachmentsIfNeeded(layoutModel: MessageLayoutModel) {
        DispatchQueue.global().async {
            fileProvider
                .downloadMessageAttachmentsIfNeeded(
                    message: layoutModel.message
                )
        }
    }
    
    //MARK: Emojis
    open func selectedEmojis(identifier: Identifier) -> [String] {
        if let model = identifier.value as? MessageLayoutModel {
            return ((model.message.userReactions?
                .sorted(by: { $0.id > $1.id })
                .map { $0.key }
                     ?? []) +
                    (model.message.userPendingReactions?
                        .sorted(by: { $0.createdAt > $1.createdAt })
                        .map { $0.key }
                     ?? [])).unique
        }
        return []
    }
    
    open func isReactionLimitReached(identifier: Identifier) -> Bool {
        guard SceytChatUIKit.shared.config.messageReactionPerUserLimit > 0
        else { return true }
        if let model = identifier.value as? MessageLayoutModel {
            return (model.message.userReactions?.count ?? 0) + (model.message.userPendingReactions?.count ?? 0) >= SceytChatUIKit.shared.config.messageReactionPerUserLimit
        }
        return false
    }
    
    open func emojis(identifier: Identifier) -> [String] {
        let emojiMaxCount = Int(SceytChatUIKit.shared.config.messageReactionPerUserLimit)
        var defaultReactions = SceytChatUIKit.shared.config.defaultReactions
        let selectedReactions = selectedEmojis(identifier: identifier)
        guard !selectedReactions.isEmpty else {
            return defaultReactions
        }
        var emojis = [String]()
        emojis.reserveCapacity(emojiMaxCount)
        emojis.append(contentsOf: selectedReactions.prefix(emojiMaxCount))
        guard emojis.count < emojiMaxCount
        else {
            return emojis
        }
        if !selectedReactions.isEmpty {
            defaultReactions.removeAll(where: {
                selectedReactions.contains($0)
            })
            emojis.append(contentsOf: defaultReactions.prefix(emojiMaxCount - selectedReactions.count))
            return emojis
        }
        return defaultReactions
        
    }
    
    open func showPlusAfterEmojis(identifier: Identifier) -> Bool {
        let selectedReactions = selectedEmojis(identifier: identifier)
        return selectedReactions.count < SceytChatUIKit.shared.config.messageReactionPerUserLimit
    }
    
    //MARK: Join channel
    open func join(_ completion: ((Error?) -> Void)?) {
        channelProvider
            .join(completion: completion)
        
    }
    
    open func refreshChannel() {
        channelObserver.refresh(at: .zero)
    }
    
    //MARK: Presence
    open func subscribeToPeerPresence() {
        if channel.isDirect, let peer = channel.peer {
            if let presence = presenceProvider.presence(userId: peer.id)?.presence {
                peerPresence = presence
            }
            presenceProvider.subscribe(userId: peer.id) { [weak self] presence in
                DispatchQueue.main.async { [weak self] in
                    guard let self
                    else { return }
                    if let peer = self.channel.peer, peer.id == presence.userId {
                        let chatUser = ChatUser(user: presence.user)
                        if chatUser !~= peer,
                           let channel = self.channelObserver.item(at: .zero),
                           channel.id == self.channel.id {
                            self.channelObserver.refresh(at: .zero)
                        }
                    }
                    self.event = .changePresence(userPresence: presence)
                    self.peerPresence = presence.presence
                }
            }
        }
    }
    
    open func unsubscribeToPeerPresence() {
        channel.members?.forEach({
            presenceProvider.unsubscribe(userId: $0.id)
        })
    }
    
    // MARK: Search
    open func startMessagesSearch() {
        if !isSearching {
            searchResult?.resetCache()
            isSearching = true
        }
    }
    
    open func stopMessagesSearch() {
        if isSearching {
            isSearching = false
            searchResult?.resetCache()
        }
        messageObserver.resetRangePredicateIfNeeded(restartObserver: false)
    }
    
    open func searchMessages(with query: String) {
        guard !query.isEmpty else {
            searchResult?.resetCache()
            return
        }
        isSearchResultsLoading = true
        
        searchResult = .init(
            channelId: channel.id, 
            searchFields: [
                .init(
                    key: .body,
                    search: .contains,
                    searchWord: query
                )
            ])
        
        searchResult.loadNextMessages({[weak self] messages, error in
            self?.searchResult.resetCache()
            guard let self, let messages, !messages.isEmpty
            else {
                self?.isSearchResultsLoading = false
                return
            }
            updateSearchedMessageFromDatabase(messages: messages) { [weak self] chatMessages in
                guard let self, !chatMessages.isEmpty
                else {
                    self?.isSearchResultsLoading = false
                    return
                }
                self.searchResult.addCache(items: chatMessages.map { $0.id }.reversed())
                if let lastFound = chatMessages.last?.id {
                    self.scrollToMessageIdIfSearching = lastFound
                    searchDirection = .next
                    self.loadNearMessagesOfSearchMessage(id: lastFound)
                }
            }
        })
    }
    
    open func findPreviousSearchedMessage() {
        guard let messageId = searchResult.prevItem() 
        else {
            logger.verbose("find prev searched message - message id not find")
            return
        }
        if let indexPath = indexPathOf(messageId: messageId) {
            searchResult.prev()
            scroll(to: indexPath, messageId: messageId)
        } else {
            scrollToMessageIdIfSearching = messageId
            searchDirection = .prev
            isSearchResultsLoading = true
            messageObserver.restartToNear(at: messageId) {[weak self] isDone in
                guard let self else { return }
                self.isSearchResultsLoading = false
                self.searchResult.prev()
                if isDone {
                    self.isRestartingMessageObserver = .reloadAndSelect
                } else if !searchResult.isLoadedNearMessages(for: messageId),
                            SceytChatUIKit.shared.chatClient.connectionState == .connected {
                    searchDirection = .prev
                    scrollToMessageIdIfSearching = messageId
                    isSearchResultsLoading = true
                    loadNearMessagesOfSearchMessage(id: messageId) {[weak self] error in
                        self?.isSearchResultsLoading = false
                        if let self, error == nil {
                            self.searchResult.setLoadedNearMessages(messageId: messageId)
                            self.searchResult.prev()
                        }
                    }
                }
            }
        }
    }
    
    open func findNextSearchedMessage() {
        guard let messageId = searchResult.nextItem()
        else {
            logger.verbose("find next searched message - message id not find")
            return
        }
        if let (index, indexPath) = cachePosition(messageId: messageId) {
            searchResult.next()
            scroll(to: indexPath, messageId: messageId)
            updateLastNavigatedIndexPath(indexPath: indexPath)
            if index < 5 {
                loadPrevMessages(before: messageId)
            }
        } else {
            let sectionsCount = numberOfSections
            scrollToMessageIdIfSearching = messageId
            searchDirection = .next
            isSearchResultsLoading = true
            messageObserver.restartToNear(at: messageId) {[weak self] isDone in
                guard let self else { return }
                self.isSearchResultsLoading = false
                if isDone {
                    self.searchResult.next()
                    self.loadNearMessages(messageId: messageId)
                } else {
                    if !searchResult.isLoadedNearMessages(for: messageId),
                                SceytChatUIKit.shared.chatClient.connectionState == .connected {
                        scrollToMessageIdIfSearching = messageId
                        searchDirection = .next
                        isSearchResultsLoading = true
                        loadNearMessagesOfSearchMessage(id: messageId) {[weak self] error in
                            self?.isSearchResultsLoading = false
                            if let self, error == nil {
                                self.searchResult.setLoadedNearMessages(messageId: messageId)
                                self.searchResult.next()
                            }
                        }
                    }
                }
            }
        }
        
        if !isSearchResultsLoading,
           searchResult.currentIndex == searchResult.cacheCount - Int(searchResult.searchQueryLimit) / 2 {
            isSearchResultsLoading = true
            searchResult.loadNextMessages({ [weak self] messages, _ in
                self?.isSearchResultsLoading = false
                guard let messages
                else { return }
                self?.updateSearchedMessageFromDatabase(messages: messages) {[weak self] chatMessages in
                    guard let self
                    else { return }
                    self.searchResult.addCache(items: chatMessages.map { $0.id }.reversed())
                }
            })
        }
    }
    
    open func findReplayedMessage(messageId: MessageId) {
        guard messageId != 0 else { return }
        scrollToRepliedMessageId = messageId
        if let (index, indexPath) = cachePosition(messageId: messageId) {
            scroll(to: indexPath, messageId: messageId)
            updateLastNavigatedIndexPath(indexPath: indexPath)
            if index < 5 {
                loadPrevMessages(before: messageId)
            }
            return
        }
        
        messageObserver
            .loadRangeProvider
            .fetchLoadRanges(
                channelId: channel.id,
                messageId: messageId)
        {[weak self] ranges in
            guard let self else { return }
            if !ranges.isEmpty {
                let sectionsCount = self.numberOfSections
                self.messageObserver.restartToNear(at: messageId) {[weak self] isDone in
                    guard let self else { return }
                    if !isDone {
                        self.loadNearMessagesOfRepliedMessage(id: messageId)
                    }
                }
            } else {
                self.loadNearMessagesOfRepliedMessage(id: messageId)
            }
        }
    }
    
    open func updateSearchedMessageFromDatabase(
        messages: [Message],
        completion: @escaping ([ChatMessage]) -> Void) {
            ChannelMessageProvider
                .updateFromDatabase(
                    messages: messages,
                    sortDescriptors: messageObserver.sortDescriptors
                ) {
                    completion($0 ?? [])
                }
        }
    
    open func indexPathOf(messageId: MessageId) -> IndexPath? {
        guard let indexPath = messageObserver.indexPath({ message in
            return message.id == messageId
        }) else { return nil }
        return indexPath
    }
    
    open func cachePosition(messageId: MessageId) -> (Int, IndexPath)? {
        var index = 0
        guard let indexPath = messageObserver.indexPath({ message in
            index += 1
            return message.id == messageId
        }) else { return nil }
        return (index, indexPath)
    }
    
    open func scroll(to indexPath: IndexPath, messageId: MessageId) {
        event = .scrollAndSelect(indexPath: indexPath, messageId: messageId)
    }
    
    //MARK: Link preview
    open func updateLinkPreviewsForLayoutModelIfNeeded(model: MessageLayoutModel) {
        let matches = DataDetector.matches(text: model.message.body)
        guard !matches.isEmpty
        else { return }
        if let linkPreviews = model.linkPreviews {
            for preview in linkPreviews where preview.isThumbnailData {
                let link = preview.url
                if let md = linkMetadataProvider.metadata(for: link) {
                    provider.storeLinkMetadata(md, to: model.message)
                } else {
                    guard let metadata = preview.metadata
                    else { return }
                    guard (metadata.image == nil || metadata.isThumbnailData)
                    else { return }
                    Task {
                        if let imageUrl = metadata.imageUrl {
                            await linkMetadataProvider.downloadImagesIfNeeded(linkMetadata: metadata)
                            self.provider.storeLinkMetadata(metadata, to: model.message)
                        } else {
                            switch await linkMetadataProvider.fetch(url: link) {
                            case .success(let data):
                                logger.verbose("Successfully loaded link Open Graph data mid: \(model.message.id) link: \(link), imageUrl: \(data.imageUrl) image: \(data.image)")
                                self.provider.storeLinkMetadata(data, to: model.message)
                            case .failure(let error):
                                logger.verbose("Failed to load link Open Graph data error: \(error)")
                            }
                        }
                    }
                }
            }
        } else if let first = model.linkAttachments.first,
                  let link = URL(string: first.attachment.url)?.normalizedURL {
            if let md = linkMetadataProvider.metadata(for: link) {
                provider.storeLinkMetadata(md, to: model.message)
            } else {
                guard !linkMetadataProvider.isFetching(url: link)
                else { return }
                Task {
                    switch await linkMetadataProvider.fetch(url: link) {
                    case .success(let data):
                        logger.verbose("Successfully loaded link Open Graph data mid: \(model.message.id) link: \(link), imageUrl: \(data.imageUrl) image: \(data.image)")
                        self.provider.storeLinkMetadata(data, to: model.message)
                    case .failure(let error):
                        logger.verbose("Failed to load link Open Graph data error: \(error)")
                    }
                }
            }
        }
    }
    
    //MARK: View
    open func select(
        message: ChatMessage,
        for action: MessageAction
    ) {
        selectedMessageForAction = (message, action)
    }
    
    open func removeSelectedMessage() {
        selectedMessageForAction = nil
    }
    
    open func separatorDateForMessage(at indexPath: IndexPath, with appearance: ChannelViewController.DateSeparatorView.Appearance) -> String? {
        let firstPath = IndexPath(row: 0, section: indexPath.section)
        guard let current = message(at: firstPath) else { return nil }
        
        guard indexPath.section > 0,
              let prev = message(at: .init(row: 0,
                                           section: indexPath.section - 1)) else {
            return appearance.dateFormatter.format(current.createdAt)
        }
        
        let calendar = Calendar.current
        let date = !calendar.isDate(prev.createdAt,
                                    equalTo: current.createdAt,
                                    toGranularity: .day) ? current.createdAt : nil
        if let date {
            return appearance.dateFormatter.format(date)
        }
        return nil
    }
    
    open var isThread: Bool {
        threadMessage != nil
    }
    
    open var isBlocked: Bool {
        guard channel.channelType == .direct,
                let members = channel.members,
              !members.isEmpty,
              !channel.isSelfChannel
        else { return false }
        return members.filter({ $0.blocked }).count >= members.count - 1 //except current user
    }
    
    open func canShowInfo(model: MessageLayoutModel) -> Bool {
        !model.message.incoming &&
        model.channel.channelType == .group
    }
    
    open func canEdit(model: MessageLayoutModel) -> Bool {
        !model.message.incoming &&
        model.message.state != .deleted &&
        (model.messageDeliveryStatus == .pending || Date().timeIntervalSince1970 - model.message.createdAt.timeIntervalSince1970 < SceytChatUIKit.shared.config.messageEditTimeout)
    }
    
    open func canReport(model: MessageLayoutModel) -> Bool {
        model.message.incoming
    }
    
    open func canDelete(model: MessageLayoutModel) -> Bool {
        !model.message.incoming
    }
    
    open func canShare(model: MessageLayoutModel) -> Bool {
        model.message.state != .deleted &&
        model.message.deliveryStatus != .pending &&
        model.messageDeliveryStatus != .pending
    }
    
    open func canReply(model: MessageLayoutModel) -> Bool {
        model.message.state != .deleted
    }
    
    // MARK: view titles
    open func getTitleForHeader(with appearance: ChannelViewController.HeaderView.Appearance) -> String {
        (isThread ?
         SceytChatUIKit.shared.formatters.userNameFormatter.format(threadMessage!.user) :
            appearance.titleFormatter.format(channel))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    open func getSubtitleForHeader(with appearance: ChannelViewController.HeaderView.Appearance) -> String {
        if channel.isSelfChannel {
            return L10n.Channel.Self.hint
        }
        let memberCount = (isThread ||
                           channel.isDirect) ? 0 : channel.memberCount
        
        return appearance.subtitleFormatter.format(channel)
    }
        
    open var draftMessage: NSAttributedString? {
        channel.draftMessage
    }
    
    private func isUpdateForView(channel: ChatChannel) -> Bool {
        if channel.subject != self.channel.subject {
            return true
        }
        if channel.memberCount != self.channel.memberCount {
            return true
        }
        if channel.userRole != self.channel.userRole {
            return true
        }
        if channel.isDirect {
            if let p1 = channel.peer, let p2 = self.channel.peer {
                if p1 !~= p2 {
                    return true
                }
                return false
            }
            return true
        }
        return false
        
    }
    
    // MARK: Channel Delegate
    
    open func channel(_ channel: Channel, didStartTyping member: Member) {
        guard self.channel.id == channel.id,
              member.id != me
        else { return }
        
        event = .typing(isTyping: true, user: .init(user: member))
        peerPresence = member.presence
        schedulers[member.id]?.stop()
        schedulers[member.id] = nil
        schedulers[member.id] = Scheduler.new(deadline: .now() + 3) { [weak self] _ in
            guard let self else { return }
            self.schedulers[member.id] = nil
            self.event = .typing(isTyping: false, user: .init(user: member))
        }
    }
    
    open func channel(_ channel: Channel, didStopTyping member: Member) {
        guard self.channel.id == channel.id,
              member.id != me
        else { return }
        event = .typing(isTyping: false, user: .init(user: member))
        peerPresence = member.presence
        schedulers[member.id]?.stop()
        schedulers[member.id] = nil
    }
    
    // MARK: ChatClient delegate
    
    open func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        if state == .connected {
            lastLoadNextMessageId = 0
            lastLoadNextMessageId = 0
            if loadLastMessagesAfterConnect {
                loadLastMessages()
                loadLastMessagesAfterConnect = false
            }
        }
        event = .connection(state: state)
    }
    
    //MARK: private section
    
    private var alreadyMarkedAsRead = false
    private func markAsReadIfNeeded() {
        guard !alreadyMarkedAsRead,
              channel.newMessageCount == 0,
              channel.unread
        else { return }
        alreadyMarkedAsRead = true
        markChannelAs(read: true)
    }
    
    @objc
    private func didUpdateLocalChannelNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let channelId = userInfo["localChannelId"] as? ChannelId,
           let channel = userInfo["channel"] as? ChatChannel,
           channelId == self.channel.id {
            updateLocalChannel(channel)
        }
    }
    
    private func updateLocalChannel(_ channel: ChatChannel, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            defer {
                completion?()
            }
            guard let self
            else { return }
            self.channel = channel
            self.provider = Components.channelMessageProvider.init(
                channelId: channel.id,
                threadMessageId: self.threadMessage?.id
            )
            self.provider.queryLimit = Self.messagesFetchLimit
            self.messageSender = Components.channelMessageSender
                .init(channelId: channel.id, threadMessageId: self.threadMessage?.id)
            self.messageMarkerProvider = Components.channelMessageMarkerProvider.init(channelId: channel.id)
            
            self.channelProvider = Components.channelProvider
                .init(channelId: channel.id)
            self.messageObserver.stopObserver()
            self.channelObserver.stopObserver()
            self.messageObserver = createMessageObserver()
            isRestartingMessageObserver = .reload
            
            startDatabaseObserver {[weak self] in
                self?.isRestartingMessageObserver = .none
            }
            for model in self.layoutModels.values {
                model.replace(channel: channel)
            }
        }
    }
    
    private func messagesCount(after id: MessageId) -> Int {
        let afterPredicate = messageObserver.fetchPredicate
            .and(predicate: .init(format: "id > %lld", lastDisplayedMessageId))
        let afterCount = messageObserver.totalCountOfItems(predicate: afterPredicate)
        return afterCount
    }
    
    private func findPrevIndexPath(
        current indexPath: IndexPath,
        cache: LazyDatabaseObserver<MessageDTO, ChatMessage>.Cache) -> IndexPath? {
            guard cache.indices.contains(indexPath.section)
            else { return nil }
            if indexPath.item > 0 {
                return .init(item: indexPath.item - 1, section: indexPath.section)
            } else if indexPath.section > 0 {
                var section = indexPath.section - 1
                while section >= 0 {
                    let nm = cache[section].count
                    if nm > 0 {
                        return .init(item: nm - 1, section: section)
                    }
                    section -= 1
                }
            }
            return nil
        }
    
    open func directChannel(userId: String, completion: ((ChatChannel?, Error?) -> Void)? = nil) {
        guard userId != me else { return }
        
        channelProvider
            .getLocalChannel(
                type: SceytChatUIKit.shared.config.channelTypesConfig.direct,
                userId: userId) { channel in
                    if let channel {
                        completion?(channel, nil)
                    } else {
                        self.channelCreator
                            .createLocalChannel(
                                type: SceytChatUIKit.shared.config.channelTypesConfig.direct,
                                members: [userId, me].map { ChatChannelMember(id: $0, roleName: SceytChatUIKit.shared.config.memberRolesConfig.owner)},
                                completion: completion
                            )
                    }
                }
    }
    
    open func directChannel(user: ChatUser,
                            completion: ((ChatChannel?, Error?) -> Void)? = nil) {
        guard user.id != me else { return }
        
        channelProvider
            .getLocalChannel(
                type: SceytChatUIKit.shared.config.channelTypesConfig.direct,
                userId: user.id) { channel in
                    if let channel {
                        completion?(channel, nil)
                    } else {
                        let member = ChatChannelMember(
                            user: user,
                            roleName: SceytChatUIKit.shared.config.memberRolesConfig.owner
                        )
                        self.channelCreator
                            .createLocalChannel(
                                type: SceytChatUIKit.shared.config.channelTypesConfig.direct,
                                members: [ChatChannelMember(id: me, roleName: SceytChatUIKit.shared.config.memberRolesConfig.owner), member],
                                completion: completion
                            )
                    }
                }
    }
    
    open func user(id: UserId,
                   completion: @escaping ((ChatUser) -> Void)) {
        Components.userProvider.init()
            .fetch(userIds: [id]) {
                completion($0.first ?? ChatUser(id: id))
            }
    }
    
    open func didChangeSelection(for indexPath: IndexPath) {
        guard isEditing, let model = layoutModel(at: indexPath)
        else { return }
        if selectedMessages.contains(model) {
            selectedMessages.remove(model)
        } else if selectedMessages.count < SceytChatUIKit.shared.config.messageMultiselectLimit {
            selectedMessages.insert(model)
        }
    }
}

public extension ChannelViewModel {
    enum MessageAction {
        case edit
        case reply
        case forward
    }
    
    enum SearchDirection {
        case none
        case next
        case prev
    }
    
    enum MessageType: String {
        case text
        case media
        case file
        case link
    }
    
    enum AttachmentType: String {
        case image
        case video
        case voice
        case file
        case link
        
        init(url: URL) {
            if url.isImage {
                self = .image
            } else if url.isAudio {
                self = .voice
            } else if url.isVideo {
                self = .video
            } else if url.isFileURL {
                self = .file
            } else {
                self = .link
            }
        }
    }
    
    enum Event {
        case update(paths: CollectionUpdateIndexPaths)
        case updateDeliveryStatus(model: MessageLayoutModel, indexPath: IndexPath)
        case reload(IndexPath)
        case reloadData
        case reloadDataAndScrollToBottom
        case reloadDataAndScroll(indexPath: IndexPath, animated: Bool, pos: CollectionView.ScrollPosition)
        case reloadDataAndSelect(indexPath: IndexPath, messageId: MessageId)
        case scrollAndSelect(indexPath: IndexPath, messageId: MessageId)
        case didSetUnreadIndexPath(indexPath: IndexPath)
        case typing(isTyping: Bool, user: ChatUser)
        case changePresence(userPresence: UserPresence)
        case updateChannel
        case showNoMessage
        case connection(state: ConnectionState)
        case close
    }
}

private extension ChannelViewModel {
    enum DataReloadingType {
        case none, reload, reloadToLatestState, reloadAndSelect
    }
}

public extension ChannelViewModel {
    
    struct Key: Equatable, Hashable {
        private let id: MessageId
        private let tid: Int64
        
        public init(message: ChatMessage) {
            id = message.id
            tid = message.tid
        }
        
        public init(messageId: MessageId) {
            id = messageId
            tid = 0
        }
        
        public static func == (lhs: Self, rhs: Self) -> Bool {
            if lhs.tid != 0, rhs.tid != 0 {
                return lhs.tid == rhs.tid
            }
            return lhs.id == rhs.id
        }
        
        public func hash(into hasher: inout Hasher) {
            if tid != 0 {
                hasher.combine(tid)
            } else if id > 0 {
                hasher.combine(id)
            }
        }
    }
}


