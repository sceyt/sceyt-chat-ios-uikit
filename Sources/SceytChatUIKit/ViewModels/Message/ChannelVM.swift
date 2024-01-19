//
//  ChannelVM.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit
import Combine

open class ChannelVM: NSObject, ChatClientDelegate, ChannelDelegate {
    //MARK: Events
    @Published public var event: Event?
    @Published public var newMessageCount: UInt64 = 0
    @Published public var peerPresence: Presence?
    
    @Published public var isEditing: Bool = false
    @Published public var selectedMessages = Set<MessageLayoutModel>()

    //MARK: Delegate identifier
    public let clientDelegateIdentifier = NSUUID().uuidString
    public let channelDelegateIdentifier = NSUUID().uuidString
    
    //MARK: public properties
    public private(set) var provider: ChannelMessageProvider
    public private(set) var messageSender: ChannelMessageSender
    public private(set) var channelCreator: ChannelCreator
    public private(set) var messageMarkerProvider: ChannelMessageMarkerProvider
    public private(set) lazy var channelProvider = Components.channelProvider
        .init(channelId: channel.id)
    
    public var chatClient: ChatClient {
        ChatClient.shared
    }
    
    public let presenceProvider = PresenceProvider.default
    public lazy var messageFetchPredicate = NSPredicate(format: "channelId == %lld AND repliedInThread == false AND replied == false AND unlisted == false", channel.id)
    
    //MARK: Message observer
    open lazy var messageObserver: LazyDatabaseObserver<MessageDTO, ChatMessage> = {
        return LazyDatabaseObserver<MessageDTO, ChatMessage>(
            context: Config.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [.init(keyPath: \MessageDTO.createdAt, ascending: true),
                              .init(keyPath: \MessageDTO.id, ascending: true)],
            sectionNameKeyPath: #keyPath(MessageDTO.daySectionIdentifier),
            fetchPredicate: messageFetchPredicate,
            relationshipKeyPathsObserver: [
                #keyPath(MessageDTO.attachments.status),
                #keyPath(MessageDTO.attachments.filePath),
                #keyPath(MessageDTO.user.avatarUrl),
                #keyPath(MessageDTO.user.firstName),
                #keyPath(MessageDTO.user.lastName),
                #keyPath(MessageDTO.parent.state),
                #keyPath(MessageDTO.bodyAttributes),
                #keyPath(MessageDTO.linkMetadatas),
            ]
        ) { [weak self] in
            let message = $0.convert()
            self?.updateUnreadIndexIfNeeded(message: message)
            self?.createLayoutModel(for: message)
            return message
        }
        
    }()
    
    //MARK: Channel observer
    open lazy var channelObserver: DatabaseObserver<ChannelDTO, ChatChannel> = {
        DatabaseObserver<ChannelDTO, ChatChannel>(
            request: ChannelDTO.fetchRequest()
                .fetch(predicate: .init(format: "id == %lld", channel.id))
                .sort(descriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)])
                .relationshipKeyPathsFor(refreshing: [
//                    #keyPath(ChannelDTO.members.user),
//                    #keyPath(ChannelDTO.members.user.blocked),
//                    #keyPath(ChannelDTO.members.user.state),
//                    #keyPath(ChannelDTO.members.user.firstName),
//                    #keyPath(ChannelDTO.members.user.lastName),
//                    #keyPath(ChannelDTO.members.user.avatarUrl)
                ]),
            context: Config.database.viewContext
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
        !(channel.userRole == Config.chatRoleOwner ||
          channel.userRole == Config.chatRoleAdmin)
    }
    
    open var isDirectChat: Bool {
        channel.channelType == .direct
    }
    
    open var isDeletedUser: Bool {
        isDirectChat && channel.peer?.state != .active
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
    public static var messagesFetchLimit: UInt = 30
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
    private var markMessagesQueue = DispatchQueue(label: "com.sceytchat.uikit.mark_messages")
    @Atomic private var lasMarkDisplayedMessageId: MessageId = 0
    @Atomic private var lastPendingMarkDisplayedMessageId: MessageId = 0
    @Atomic private var isAppActive: Bool = true
    @Atomic private var isRestartingMessageObserver: Bool = false
    
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
        chatClient.add(
            channelDelegate: self,
            identifier: channelDelegateIdentifier
        )
        chatClient.add(
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
    }
    
    //MARK: deinit
    deinit {
        logger.verbose("ChannelVM deinit for channel \(channel.id)")
        channelObserver.stopObserver()
        messageObserver.stopObserver()
//        unsubscribeToPeerPresence()
        chatClient.removeDelegate(identifier: clientDelegateIdentifier)
        chatClient.removeChannelDelegate(identifier: channelDelegateIdentifier)
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
            self?.onDidChangeEvent(items: $0, events: ($1 as? [Event]) ?? [])
        }
        
        channelObserver.onDidChange = { [weak self] in
            self?.onDidChangeChannelEvent(items: $0)
        }
        do {
            let fetchOffset = calculateMessageFetchOffset(messageId: lastDisplayedMessageId)
            try messageObserver.startObserver(fetchOffset: fetchOffset, fetchLimit: Int(Self.messagesFetchLimit), completion: completion)
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
            
        } catch {
            logger.errorIfNotNil(error, "observer.startObserver")
        }
    }
    
    open func updateUserInfo(
        indexPath: IndexPath,
        message: ChatMessage,
        prevIndexPath: IndexPath?,
        prevMessage: ChatMessage?,
        nextIndexPath: IndexPath?,
        nextMessage: ChatMessage?) {
            guard channel.isGroup
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
        items: LazyDatabaseObserver<MessageDTO, ChatMessage>.ChangeItemPaths
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
                            items: LazyDatabaseObserver<MessageDTO, ChatMessage>.ChangeItemPaths)
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
                        events.append(.updateDeliveryStatus(model, indexPath))
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
            } else {
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
            events.append(.didSetUnreadIndexPath(indexPath))
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
    
    open func onDidChangeEvent(
        items: LazyDatabaseObserver<MessageDTO, ChatMessage>.ChangeItemPaths,
        events: [Event]) {
            if numberOfSections == 0 {
                event = .showNoMessage
            }
            if isRestartingMessageObserver {
                event = .reloadData
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
                    event = .reloadDataAndScroll(indexPath)
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
                lastDisplayedMessageId: lastDisplayedMessageId)
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
                lastDisplayedMessageId: lastDisplayedMessageId)
        
        layoutModels[.init(message: lastMessage)] = model
    }
    
    //MARK: Typing
    
    open var isTyping = false {
        didSet { isTyping ? provider.channelOperator.startTyping() : provider.channelOperator.stopTyping() }
    }
    
    //MARK: load messages
    
    open func calculateMessageFetchOffset(messageId: MessageId = 0) -> Int {
        var fetchOffset: Int
        if messageId == 0 {
            fetchOffset = messageObserver.totalCountOfItems() - Int(Self.messagesFetchLimit)
        } else {
            let beforePredicate = messageObserver.fetchPredicate
                .and(predicate: .init(format: "id < %lld", messageId))
            let beforeCount = messageObserver.totalCountOfItems(predicate: beforePredicate)
            fetchOffset = beforeCount
            let afterCount = messageObserver.totalCountOfItems() - fetchOffset
            if  afterCount < Self.messagesFetchLimit {
                fetchOffset -= Int(Self.messagesFetchLimit) - afterCount
            }
        }
        return max(fetchOffset, 0)
    }
    
    open func loadLastMessages() {
        if isUnsubscribedChannel {
            loadPrevMessages(before: MessageId(Int64.max))
        } else {
            if isThread || channel.lastMessage?.incoming == false || lastDisplayedMessageId == 0 {
                logger.info("ChannelVM loadLastMessages (prev) channel id: \(channel.id), lastMessage id \(channel.lastMessage?.id as Any)")
                provider.loadPrevMessages(before: channel.lastMessage?.id ?? MessageId(Int64.max))
            } else {
                logger.info("ChannelVM loadLastMessages (near) channel id: \(channel.id), lastDisplayedMessageId \(lastDisplayedMessageId)")
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
        logger.info("ChannelVM loadLastMessages (next) channel id: \(channel.id), \(indexPath) lastDisplayedMessageId \(message.id) \(message.body)")
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
        messageObserver.loadPrev { [weak self] in
            self?.isFetchingData = false
        }
        provider.loadPrevMessages(
            query: provider.makeQuery(),
            before: messageId
        ) {[weak self] error in
            if error != nil {
                self?.lastLoadPrevMessageId = 0
            }
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
        messageObserver.loadNext { [weak self] in
            self?.isFetchingData = false
        }
        provider.loadNextMessages(
            after: messageId
        ) {[weak self] error in
            if error != nil {
                self?.lastLoadNextMessageId = 0
            }
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
    
    open func loadAllToShowMessage(messageId: MessageId,
                                   completion: (() -> Void)? = nil) {
        let offset = max(calculateMessageFetchOffset(messageId: messageId) - 10, 0)
        let limit = messageObserver.fetchOffset - offset
        guard limit > 0 else { return }
        messageObserver.load(from: offset, limit: limit) {
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    //MARK: mark messages
    open func markMessageAsDisplayed(indexPaths: [IndexPath]) {
        guard !indexPaths.isEmpty
        else { return }
        markMessagesQueue.async {[weak self] in
            guard let self
            else { return }
            
            let message: ChatMessage? = indexPaths.compactMap {
                if let message = self.message(at: $0),
                   message.id != 0 {
                    return message
                }
                return nil
            }.max(by: { $0.id < $1.id })
            
            guard let message, self.lasMarkDisplayedMessageId != message.id
            else { return }
            logger.verbose("[MARKER CHECK], ChannelVM markMessageAsDisplayed from message id: \(message.id), \(message.body), last: \(self.lasMarkDisplayedMessageId)")
            let prevLasMarkDisplayedMessageId = self.lasMarkDisplayedMessageId
            self.lasMarkDisplayedMessageId = message.id
            let semafore = DispatchSemaphore(value: 1)
            self.messageMarkerProvider.markIfNeeded(
                after: prevLasMarkDisplayedMessageId,
                before: message.id,
                markerName: DefaultMarker.displayed)
            { error in
                semafore.signal()
            }
            semafore.wait()
            
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
        if userMessage.text.count < 10 || userMessage.text.count > 0 && (userMessage.text as NSString).length == 0 {
            let data = Data(userMessage.text.utf8)
            let hexString = data.map{ String(format:"%02x", $0) }.joined()
            logger.verbose("[EMPTY] Prepare Send text message by hex [\(hexString)] orig [\(userMessage.text)]")
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
            .type(userMessage.type.rawValue)
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
        provider.storePending(message: message)
        
        @Sendable func send() {
            switch action {
            case .send, .reply, .forward:
                messageSender.sendMessage(message, storeBeforeSend: false)
            case .edit:
                messageSender.editMessage(message, storeBeforeSend: false)
            }
        }
        
        if channel.unSynched {
            Task {
                do {
                    if let channel = try await channelCreator.createChannelOnServerIfNeeded(channelId: channel.id) {
                        updateLocalChannel(channel) {
                            send()
                        }
                    } else {
                        send()
                    }
                } catch {
                    
                }   
            }
        } else {
            send()
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
        forMeOnly: Bool
    ) {
        layoutModel.message.attachments?.forEach {
            AttachmentTransfer.default.taskFor(message: layoutModel.message, attachment: $0)?.cancel()
        }
        if layoutModel.message.deliveryStatus == .pending {
            provider.deletePending(message: layoutModel.message.tid)
        } else {
            messageSender.deleteMessage(id: layoutModel.message.id, forMeOnly: forMeOnly)
        }
    }
    
    open func deleteSelectedMessages(forMeOnly: Bool) {
        selectedMessages.forEach {
            deleteMessage(layoutModel: $0, forMeOnly: forMeOnly)
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
        guard Config.maxAllowedEmojisCount > 0
        else { return true }
        if let model = identifier.value as? MessageLayoutModel {
            return (model.message.userReactions?.count ?? 0) + (model.message.userPendingReactions?.count ?? 0) >= Config.maxAllowedEmojisCount
        }
        return false
    }
    
    open func emojis(identifier: Identifier) -> [String] {
        let emojiMaxCount = Int(Config.maxAllowedEmojisCount)
        var defaultEmojis = Config.defaultEmojis
        let selectedReactions = selectedEmojis(identifier: identifier)
        guard !selectedReactions.isEmpty else {
            return defaultEmojis
        }
        var emojis = [String]()
        emojis.reserveCapacity(emojiMaxCount)
        emojis.append(contentsOf: selectedReactions.prefix(emojiMaxCount))
        guard emojis.count < emojiMaxCount
        else {
            return emojis
        }
        if !selectedReactions.isEmpty {
            defaultEmojis.removeAll(where: {
                selectedReactions.contains($0)
            })
            emojis.append(contentsOf: defaultEmojis.prefix(emojiMaxCount - selectedReactions.count))
            return emojis
        }
        return defaultEmojis
        
    }
    
    open func showPlusAfterEmojis(identifier: Identifier) -> Bool {
        let selectedReactions = selectedEmojis(identifier: identifier)
        return selectedReactions.count < Config.maxAllowedEmojisCount
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
        if !channel.isGroup, let peer = channel.peer {
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
                    self.event = .changePresence(presence.presence)
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
    
    open func separatorDateForMessage(at indexPath: IndexPath) -> String? {
        let firstPath = IndexPath(row: 0, section: indexPath.section)
        guard let current = message(at: firstPath)
        else { return nil }
        guard indexPath.section > 0,
              let prev = message(at: .init(row: 0,
                                           section: indexPath.section - 1))
        else {
            return Formatters.messageListSeparator.format(current.createdAt, showYear: false) 
        }
        
        let calendar = Calendar.current
        
        let date = !calendar.isDate(
            prev.createdAt,
            equalTo: current.createdAt,
            toGranularity: .day
        ) ? current.createdAt : nil
        if let date {
            let dateYear = calendar.component(.year, from: date)
            let currentYear = calendar.component(.year, from: Date())
            return Formatters.messageListSeparator.format(date, showYear: dateYear < currentYear)
            
        }
        return nil
    }
    
    open var isThread: Bool {
        threadMessage != nil
    }
    
    open var isBlocked: Bool {
        guard channel.channelType == .direct,
                let members = channel.members,
              !members.isEmpty
        else { return false }
        return members.filter({ $0.blocked }).count >= members.count - 1 //except current user
    }
    
    open func canShowInfo(model: MessageLayoutModel) -> Bool {
        !model.message.incoming &&
        model.channel.channelType == .private
    }
    
    open func canEdit(model: MessageLayoutModel) -> Bool {
        !model.message.incoming &&
        model.message.state != .deleted &&
        (model.messageDeliveryStatus == .pending || Date().timeIntervalSince1970 - model.message.createdAt.timeIntervalSince1970 < Config.messagePossibleEditIn)
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
    open var title: String {
        (isThread ?
         Formatters.userDisplayName.format(threadMessage!.user) :
            Formatters.channelDisplayName.format(channel))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    open var subTitle: String? {
        let memberCount = (isThread ||
                           !channel.isGroup) ? 0 : channel.memberCount
        var subTitle: String?
        
        switch memberCount {
        case 1:
            if channel.channelType == .private {
                subTitle = L10n.Channel.MembersCount.one
            } else {
                subTitle = L10n.Channel.SubscriberCount.one
            }
        case 2...:
            if channel.channelType == .private {
                subTitle = L10n.Channel.MembersCount.more(Int(memberCount))
            } else {
                subTitle = L10n.Channel.SubscriberCount.more(Int(memberCount))
            }
        default:
            if let presence = peerPresence {
                subTitle = Formatters.userPresenceFormatter.format(presence)
            } else if let presence = channel.peer?.presence {
                subTitle = Formatters.userPresenceFormatter.format(presence)
            }
        }
        return subTitle
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
        if !channel.isGroup {
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
        
        event = .typing(true, .init(user: member))
        peerPresence = member.presence
        schedulers[member.id]?.stop()
        schedulers[member.id] = nil
        schedulers[member.id] = Scheduler.new(deadline: .now() + 3) { [weak self] _ in
            guard let self else { return }
            self.schedulers[member.id] = nil
            self.event = .typing(false, .init(user: member))
        }
    }
    
    open func channel(_ channel: Channel, didStopTyping member: Member) {
        guard self.channel.id == channel.id,
              member.id != me
        else { return }
        event = .typing(false, .init(user: member))
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
        event = .connection(state)
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
            self.provider = Components.channelMessageProvider.init(
                channelId: channel.id,
                threadMessageId: self.threadMessage?.id
            )
            self.provider.queryLimit = Self.messagesFetchLimit
            self.messageSender = Components.channelMessageSender
                .init(channelId: channel.id, threadMessageId: self.threadMessage?.id)
            self.messageMarkerProvider = Components.channelMessageMarkerProvider.init(channelId: channel.id)
            self.messageFetchPredicate = NSPredicate(format: "channelId == %lld AND repliedInThread == false AND replied == false AND unlisted == false", channel.id, channel.id)
            self.channelProvider = Components.channelProvider
                .init(channelId: channel.id)
            isRestartingMessageObserver = true
            try? self.messageObserver.restartObserver(fetchPredicate: self.messageFetchPredicate) {[weak self] in
                self?.isRestartingMessageObserver = false
                
            }
            self.channel = channel
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
                type: Config.directChannel,
                userId: userId) { channel in
                    if let channel {
                        completion?(channel, nil)
                    } else {
                        self.channelCreator
                            .createLocalChannel(
                                type: "direct",
                                members: [userId, me].map { ChatChannelMember(id: $0, roleName: Config.chatRoleOwner)},
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
                type: Config.directChannel,
                userId: user.id) { channel in
                    if let channel {
                        completion?(channel, nil)
                    } else {
                        let member = ChatChannelMember(
                            user: user,
                            roleName: Config.chatRoleOwner
                        )
                        self.channelCreator
                            .createLocalChannel(
                                type: "direct",
                                members: [ChatChannelMember(id: me, roleName: Config.chatRoleOwner), member],
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
        } else if selectedMessages.count < SCTUIKitConfig.maximumMessagesToSelect {
            selectedMessages.insert(model)
        }
    }
}

public extension ChannelVM {
    enum MessageAction {
        case edit
        case reply
        case forward
    }
    
    enum RequestType {
        case none
        case near
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
        case updateDeliveryStatus(MessageLayoutModel, IndexPath)
        case reload(IndexPath)
        case reloadData
        case reloadDataAndScrollToBottom
        case reloadDataAndScroll(IndexPath)
        case didSetUnreadIndexPath(IndexPath)
        case typing(Bool, ChatUser)
        case changePresence(Presence)
        case updateChannel
        case showNoMessage
        case connection(ConnectionState)
        case close
    }
}

public extension ChannelVM {
    
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
