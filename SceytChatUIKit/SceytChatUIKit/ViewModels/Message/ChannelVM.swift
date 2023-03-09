//
//  ChannelVM.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat


open class ChannelVM: NSObject, ChatClientDelegate, ChannelDelegate {

    @Published public var event: Event?
    @Published public var peerPresence: Presence?
    
    public let clientDelegateIdentifier = NSUUID().uuidString
    public let channelDelegateIdentifier = NSUUID().uuidString

    public let provider: ChannelMessageProvider
    public let messageSender: ChannelMessageSender
    public private(set) lazy var channelProvider: ChannelProvider =
    ChannelProvider(channelId: channel.id)

    public var chatClient: ChatClient {
        ChatClient.shared
    }
    
    private let presenceProvider = PresenceProvider.default.copy() as! PresenceProvider

    open lazy var messageObserver: DatabaseObserver<MessageDTO, ChatMessage> = {
        let request = isThread ?
        MessageDTO.fetchRequest()
            .fetch(predicate: .init(format: "parent.id == %lld AND repliedInThread == true", threadMessage!.id))
            .sort(descriptors: [.init(keyPath: \MessageDTO.createdAt, ascending: true)]) :
        MessageDTO.fetchRequest()
            .fetch(predicate: .init(format: "ownerChannel.id == %lld AND repliedInThread == false", channel.id))
            .sort(descriptors: [.init(keyPath: \MessageDTO.createdAt, ascending: true)])
            .relationshipKeyPathsFor(refreshing: [#keyPath(MessageDTO.attachments.status)])
        return DatabaseObserver<MessageDTO, ChatMessage>(
            request: request,
            context: Config.database.viewContext,
            sectionNameKeyPath: #keyPath(MessageDTO.daySectionIdentifier)
        ) { $0.convert() }
        
    }()
    
    open lazy var channelObserver: DatabaseObserver<ChannelDTO, ChatChannel> = {
        
        DatabaseObserver<ChannelDTO, ChatChannel>(
            request: ChannelDTO.fetchRequest()
                .fetch(predicate: .init(format: "id == %lld", channel.id))
                .sort(descriptors: [.init(keyPath: \ChannelDTO.sortingKey, ascending: false)])
                .relationshipKeyPathsFor(refreshing: [
                    #keyPath(ChannelDTO.peer.blocked),
                    #keyPath(ChannelDTO.peer.activityState),
                    #keyPath(ChannelDTO.peer.firstName),
                    #keyPath(ChannelDTO.peer.lastName),
                    #keyPath(ChannelDTO.peer.avatarUrl)
                ]),
            context: Config.database.viewContext) { $0.convert() }
    }()

    open lazy var linkMetadataProvider = LinkMetadataProvider
        .init()
    
    open lazy var previewer = AttachmentPreviewDataSource(channel: channel, ascending: true)

    public let attachmentUploadInfo = MessageAttachmentUploadInfo.default
    open var isUnsubscribedChannel: Bool {
        guard channel.type == .public else { return false }
        return channel.roleName == nil
    }

    public private(set) var channel: ChatChannel {
        didSet {
            event = .updateChannel
            event = .unreadCount(channel.unreadMessageCount)
        }
    }
    public let threadMessage: ChatMessage?
    public private(set) var layoutModels = [Key: MessageLayoutModel]()
    
    public var loadLastMessagesAfterConnect = true
    public let lastDisplayedMessageId: MessageId
    public private(set) var lastRequestType: RequestType = .none
    public private(set) var selectedMessageForAction: (ChatMessage, MessageAction)?
    
    open var hasUnreadMessages: Bool {
        channel.unreadMessageCount > 0
    }
    
    open var canShowMessageSenderInfoForDirectChannel = false
    open var cacheMarkerForSendLater = false
    
    private var hasSendScrollPosition = false
    private var pendingMarkerMessageIds = Set<MessageId>()
    private var schedulers = [UserId: Scheduler]()
    public required init(
        channel: ChatChannel,
        threadMessage: ChatMessage? = nil
    ) {
        provider = ChannelMessageProvider(
            channelId: channel.id,
            threadMessageId: threadMessage?.id
        )
        messageSender = ChannelMessageSender(
            channelId: channel.id,
            threadMessageId: threadMessage?.id
        )
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
        event = .unreadCount(channel.unreadMessageCount)
        subscribeToPeerPresence()
    }

    deinit {
        unsubscribeToPeerPresence()
        chatClient.removeDelegate(identifier: clientDelegateIdentifier)
        chatClient.removeChannelDelegate(identifier: channelDelegateIdentifier)
        if isTyping {
            isTyping = false
        }
    }

    open func startDatabaseObserver() {
        messageObserver.onDidChange = { [weak self] in
            self?.onDidChangeEvent(items: $0)
        }
        channelObserver.onDidChange = { [weak self] in
            self?.onDidChangeChannelEvent(items: $0)
        }
        do {
            try messageObserver.startObserver()
            try channelObserver.startObserver()
        } catch {
            debugPrint("observer.startObserver", error)
        }
    }

    open func onDidChangeEvent(items: DBChangeItemPaths) {
        if messageObserver.isEmpty {
            event = .reloadData
            return
        }
        @discardableResult
        func updateLayoutModel(at indexPath: IndexPath) -> Bool {
            var isUpdated = false
            guard let message = message(at: indexPath)
            else { return isUpdated }
            if lastDisplayedMessageId != 0,
                !hasSendScrollPosition,
                message.id == lastDisplayedMessageId {
                hasSendScrollPosition = true
                event = .didSetUnreadIndexPath(indexPath)
            }
            if let model = layoutModel(at: indexPath) {
                if !model.update(channel: channel, message: message) {
                    layoutModels[.init(message: message)] = nil
                }
                var updateOptions = model.updateOptions
                if updateOptions.contains(.deliveryStatus) {
                    updateOptions.remove(.deliveryStatus)
                    event = .updateDeliveryStatus(model.messageDeliveryStatus, indexPath)
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
    
        items.inserts.forEach { indexPath in
            updateLayoutModel(at: indexPath)
        }
        items.updates.forEach { indexPath in
            if !updateLayoutModel(at: indexPath) {
                paths.reloads.removeAll(where: {$0 == indexPath })
            }
        }
        items.deletes.forEach { indexPath in
            updateLayoutModel(at: indexPath)
        }
        items.moves.forEach { fromIndexPath, toIndexPath in
            updateLayoutModel(at: fromIndexPath)
            updateLayoutModel(at: toIndexPath)
        }
        guard !paths.isEmpty else { return }
        event = .update(paths: paths)
    }
    
    open func onDidChangeChannelEvent(items: DBChangeItemPaths) {
        let channels: [ChatChannel]? = items.items()
        guard let ch = channels?.first(where: { $0.id == channel.id })
        else { return }
        if channel.roleName != nil,
            ch.roleName == nil {
            event = .close
        }
        channel = ch
        
    }
    
    @discardableResult
    open func createLayoutModels(at indexPaths: [IndexPath]) -> [MessageLayoutModel] {
        var models = [MessageLayoutModel]()
        for indexPath in indexPaths {
            guard let message = message(at: indexPath),
                  layoutModels[.init(message: message)] == nil
            else { continue }
            print("[DEBUG] performance", indexPath)
            let model = Components.messageLayoutModel.init(channel: channel, message: message)
            models.append(model)
            layoutModels[.init(message: message)] = model
        }
        return models
    }

    open var numberOfSection: Int {
        messageObserver.numberOfSection
    }

    open func numberOfMessages(in section: Int) -> Int {
        messageObserver.numberOfItems(in: section)
    }
    
    private func findPrevIndexPath(current indexPath: IndexPath) -> IndexPath? {
        guard numberOfSection > 0,
              indexPath.section < numberOfSection
        else { return nil }
        if indexPath.item > 0 {
            return .init(item: indexPath.item - 1, section: indexPath.section)
        } else if indexPath.section > 0 {
            var section = indexPath.section - 1
            while section >= 0 {
                let nm = numberOfMessages(in: section)
                if nm > 0 {
                    return .init(item: nm - 1, section: section)
                }
                section -= 1
            }
        }
        return nil
    }
   
    open func message(at indexPath: IndexPath) -> ChatMessage? {
        messageObserver.item(at: indexPath)
    }
    
    open func indexPath(for message: ChatMessage) -> IndexPath? {
        for section in 0 ..< messageObserver.numberOfSection {
            for item in 0 ..< messageObserver.numberOfItems(in: section) {
                let indexPath = IndexPath(item: item, section: section)
                if let found = messageObserver.item(at: indexPath),
                   found.id == message.id {
                    return indexPath
                }
            }
        }
        return nil
    }

    open func layoutModel(at indexPath: IndexPath) -> MessageLayoutModel? {
        guard let message = message(at: indexPath)
        else { return nil }
        if let model = layoutModels[.init(message: message)] {
            return model
        }
        return nil
    }
    
    @discardableResult
    open func selectMessage(
        at indexPath: IndexPath,
        for action: MessageAction
    ) -> Bool {
        if let message = message(at: indexPath) {
            selectedMessageForAction = (message, action)
            return true
        }
        return false
    }
    
    open func removeSelectedMessage() {
        selectedMessageForAction = nil
    }

    open func separatorDateForMessage(at indexPath: IndexPath) -> Date? {
        let firstPath = IndexPath(row:0, section: indexPath.section)
        guard let current = message(at: firstPath)
        else { return nil }
        guard indexPath.section > 0,
                let prev = message(at: .init(row: 0,
                                     section: indexPath.section - 1))
        else {
            return current.createdAt
        }
        return !Calendar.current.isDate(
            prev.createdAt,
            equalTo: current.createdAt,
            toGranularity: .day
        ) ? current.createdAt : nil
    }

    open func canShowMessageSenderInfo(messageAt indexPath: IndexPath) -> Bool {
        
        if !canShowMessageSenderInfoForDirectChannel,
            channel.type == .direct {
            return false
        }
        
        if indexPath.item == 0 {
            return true
        }
        
        guard let next = findPrevIndexPath(current: indexPath),
              let prev = message(at: next)
        else { return true }
        if let current = message(at: indexPath),
           prev.user.id != current.user.id {
            return true
        }
        return false
    }

    open func canShowUnreadSeparatorForMessage(at indexPath: IndexPath) -> Bool {
        guard lastDisplayedMessageId != 0
        else { return false }
        guard let prev = findPrevIndexPath(current: indexPath),
                let message = message(at: prev)
        else { return false }
        return lastDisplayedMessageId == message.id
    }

    open var isThread: Bool {
        threadMessage != nil
    }

    open var isTyping = false {
        didSet { isTyping ? provider.channelOperator.startTyping() : provider.channelOperator.stopTyping() }
    }

    open func loadLastMessages() {
        if isUnsubscribedChannel {
            loadPrevMessages()
        } else {
            if isThread || channel.lastMessage?.incoming == false {
                lastRequestType = .prev
//                lastDisplayedMessageId = 0
                provider.loadPrevMessages(before: 0) { [weak self] _ in
                    self?.lastRequestType = .none
                }
            } else {
                lastRequestType = .near
                provider.loadNearMessages(near: channel.lastDisplayedMessageId) { [weak self] _ in
                    self?.lastRequestType = .none
                }
            }
        }
    }

    open func loadPrevMessages() {
        lastRequestType = .prev
        provider.loadPrevMessages { [weak self] _ in
            self?.lastRequestType = .none
        }
    }

    open func loadNextMessages() {
        lastRequestType = .next
        provider.loadNextMessages { [weak self] _ in
            self?.lastRequestType = .none
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
        guard let message = message(at: findPrevIndexPath(current: indexPath) ?? indexPath)
        else { return }
        loadNextMessages(after: message.id)
    }
    
    open func loadPrevMessages(
        before messageId: MessageId
    ) {
        lastRequestType = .prev
        provider.loadPrevMessages(
            query: provider.makeQuery(),
            before: messageId
        ) { [weak self] _ in
            self?.lastRequestType = .none
        }
    }

    open func loadNextMessages(
        after messageId: MessageId
    ) {
        lastRequestType = .next
        provider.loadNextMessages(
            query: provider.makeQuery(),
            after: messageId
        ) { [weak self] _ in
            self?.lastRequestType = .none
        }
    }
    
    open func loadNearMessages(
        nearMessageAt indexPath: IndexPath
    ) {
        guard let message = message(at: indexPath)
        else { return }
        loadNearMessages(messageId: message.id)
    }
    
    open func loadNearMessages(
        messageId: MessageId
    ) {
        lastRequestType = .near
        provider.loadNearMessages(
            query: provider.makeQuery(),
            near: messageId
        ) { [weak self] _ in
            self?.lastRequestType = .none
        }
    }
    
    open func markMessageAsDisplayed(at indexPaths: [IndexPath]) {
        let markableMessageIds: [MessageId] = indexPaths.compactMap {
            guard let message = message(at: $0),
                  message.incoming,
                  !message.hasDisplayedFromMe,
                  !pendingMarkerMessageIds.contains(message.id)
            else { return nil }
            pendingMarkerMessageIds.insert(message.id)
            guard !cacheMarkerForSendLater else { return nil }
            return message.id
        }
        markMessageAsDisplayed(ids: markableMessageIds)
    }
    
    open func markMessageAsDisplayed(ids: [MessageId]) {
        let chunked = Array(ids).chunked(into: 50)
        chunked.forEach {
            provider.markMessagesAsDisplayed(ids: Array($0)) { [weak self] error in
                if error == nil {
                    ids.forEach {
                        self?.pendingMarkerMessageIds.remove($0)
                    }
                }
            }
        }
    }
    
    open func markChannelAsDisplayed() {
        channelProvider
            .markAs(read: true)
        if let id = channel.lastMessage?.id {
            provider.markMessagesAsDisplayed(ids: [id])
        }
    }
    
    open func sendCachedMarkers() {
        markMessageAsDisplayed(ids: Array(pendingMarkerMessageIds))
    }

    open func createAndSendUserMessage(_ userMessage: UserSendMessage) {
        lastRequestType = .none
        if isTyping {
            isTyping = false
        }
        if case .edit(let message) = userMessage.action,
           message.body == userMessage.text {
            return
        }
        
        let builder = Message
            .Builder()
            .type(userMessage.type.rawValue)

        switch userMessage.action {
        case let .edit(message):
            builder.id(message.id)

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
            builder.attachments(linkAttachment)
            messages.append(builder.build())
        }
        guard !messages.isEmpty else { return }
        
        func send(message: Message) {
            switch userMessage.action {
            case .send, .reply, .forward:
                self.messageSender.sendMessage(message)
            case .edit:
                self.messageSender.editMessage(message)
            }
        }
        
        let first = messages.remove(at: 0)
        send(message: first)
        
        for index in 0 ..< messages.count {
            DispatchQueue
                .global(qos: .userInteractive)
                .asyncAfter(deadline: .now() + TimeInterval(1 * index)) {
                    send(message: messages[index])
            }
        }
    }
   
    open func sendUserMessage(
        _ message: Message,
        action: UserSendMessage.Action
    ) {
        switch action {
        case .send, .reply, .forward:
            messageSender.sendMessage(message)
        case .edit:
            messageSender.editMessage(message)
        }
    }
    
    open func forward(
        message: ChatMessage,
        to channelIds: [ChannelId]) {
            let builder = message.builder
            builder.id(0)
            builder.tid(0)
            builder.forwardingMessageId(message.id)
            for channelId in channelIds {
                let message = builder.build()
                ChannelMessageSender(channelId: channelId)
                    .sendMessage(message)
            }
        }
    
    open func deleteMessage(
        at indexPath: IndexPath,
        forMeOnly: Bool
    ) {
        guard let message = message(at: indexPath)
        else { return }
        if message.deliveryStatus == .pending {
            provider.deletePending(message: message.id)
        } else {
            messageSender.deleteMessage(id: message.id, forMeOnly: forMeOnly)
        }
    }

    open func addReaction(
        at indexPath: IndexPath,
        key: String, score: UInt16 = 1
    ) {
        if let message = message(at: indexPath) {
            provider.addReactionToMessage(id: message.id, key: key, score: score)
        }
    }

    open func canDeleteReaction(
        at indexPath: IndexPath,
        key: String
    ) -> Bool {
        if let message = message(at: indexPath) {
            return message.selfReactions?.contains(where: { $0.key == key }) == true
        }
        return false
    }
    
    open func deleteReaction(
        at indexPath: IndexPath,
        key: String
    ) {
        if let message = message(at: indexPath) {
            provider.deleteReactionFromMessage(
                id: message.id,
                key: key
            )
        }
    }

    open func selectedEmojis(at indexPath: IndexPath) -> [String] {
        if let message = message(at: indexPath) {
            return message.selfReactions?.map { $0.key } ?? []
        }
        return []
    }

    open func join(_ completion: ((Error?) -> Void)?) {
        guard channel.type == .public
        else { return }
        channelProvider
        .join(completion: completion)
    }
    
    open func updateDraftMessage( _ message: NSAttributedString?) {
//        channelProvider.saveDraftMessage(message)
    }
    
    open func subscribeToPeerPresence() {
        if channel.type == .direct,
            let peer = channel.peer {
            presenceProvider.subscribe(userId: peer.id) { [weak self] presence in
                DispatchQueue.main.async {
                    self?.event = .changePresence(presence.presence)
                    self?.peerPresence = presence.presence
                }
            }
        }
    }
    
    open func unsubscribeToPeerPresence() {
        if channel.type == .direct,
            let peer = channel.peer {
            presenceProvider.unsubscribe(userId: peer.id)
        }
    }

    open func updateLinkPreviewsForLayoutModelIfNeeded(_ model: MessageLayoutModel, at indexPath: IndexPath) {
        guard let message = message(at: indexPath)
        else { return }
        guard !model.links.isEmpty,
                model.linkPreviews == nil,
                model.attachmentCount.isEmpty,
                let first = model.links.first else { return }
        var loads = [URL]()
        if let md = linkMetadataProvider.metadata(for: first) {
            _ = model.addLinkPreview(linkMetadata: md)
            provider.storeLinkMetadata(md, to: message)
        } else {
            loads.append(first)
        }
        if model.linkPreviews != nil {
            DispatchQueue.main.async {
                self.event = .reload(indexPath)
            }
            return
        }

        loads.forEach {
            linkMetadataProvider.fetch(url: $0) {[weak self] result in
                guard let self = self, case .success(let md) = result else { return }
                if model.addLinkPreview(linkMetadata: md) {
                    self.provider.storeLinkMetadata(md, to: message)
                }
                self.event = .reload(indexPath)
            }
        }
    }
    
    open func stopFileTransfer(messageAt indexPath: IndexPath, attachmentAt index: Int) {
        if let model = layoutModel(at: indexPath), let attachments = model.sortedAttachments, index < attachments.count {
            fileProvider.stopTransfer(message: model.message, attachment: attachments[index])
        }
    }
    
    open func resumeFileTransfer(messageAt indexPath: IndexPath, attachmentAt index: Int) {
        if let model = layoutModel(at: indexPath), let attachments = model.sortedAttachments, index < attachments.count {
            fileProvider.resumeTransfer(message: model.message, attachment: attachments[index])
        }
    }
    
    //MARK: view titles
    open var title: String {
        (isThread ?
         Formatters.userDisplayName.format(threadMessage!.user) :
            Formatters.channelDisplayName.format(channel))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    open var subTitle: String? {
        let memberCount = (isThread ||
                           channel.type == .direct) ? 0 : channel.memberCount
        var subTitle: String?
        
        switch memberCount {
        case 1:
            if channel.type == .private {
                subTitle = L10n.Channel.MembersCount.one
            } else {
                subTitle = L10n.Channel.SubscriberCount.one
            }
        case 2...:
            if channel.type == .private {
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
    
    // MARK: ChannelDelegate
    open func channel(_ channel: Channel, didStartTyping member: Member) {
        guard self.channel.id == channel.id,
              member.id != me
        else { return }
        
        event = .typing(true, .init(user: member))
        peerPresence = member.presence
        schedulers[member.id]?.stop()
        schedulers[member.id] = nil
        schedulers[member.id] = Scheduler.new(deadline: .now() + 3) {[weak self] s in
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

    // MARK: ChatClientDelegate
    open func chatClient(_ chatClient: ChatClient, didChange state: ConnectionState, error: SceytError?) {
        if state == .connected {
            if loadLastMessagesAfterConnect {
                loadLastMessages()
            } else {
                loadNextMessages()
            }
        }
        event = .connection(state)
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
        case updateDeliveryStatus(ChatMessage.DeliveryStatus, IndexPath)
        case reload(IndexPath)
        case reloadData
        case didSetUnreadIndexPath(IndexPath)
        case unreadCount(UInt64)
        case typing(Bool, ChatUser)
        case changePresence(Presence)
        case updateChannel
        case connection(ConnectionState)
        case close
    }
}

extension ChannelVM {

    public struct Key: Equatable, Hashable {
        private let id: MessageId
        private let tid: Int64
        init(message: ChatMessage) {
            id = message.id
            tid = message.tid
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
