//
//  SceytChatUIKit+UITestSupport.swift
//  SceytChatUIKit
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//
//  DEBUG-only test support. This file is compiled out of release builds, so the
//  seeding/bypass entry points can never be reached by shipping app code.
//

#if DEBUG
import CoreData
import Foundation
import SceytChat

extension SceytChatUIKit {

    /// A declarative description of a channel to seed into the local database for
    /// UI tests. Plain value types only, so the host app needs nothing beyond a
    /// normal `import SceytChatUIKit`.
    public struct UITestChannelSeed {

        public var id: ChannelId
        public var subject: String
        public var lastMessageText: String?
        public var lastMessageIsIncoming: Bool
        public var lastMessageDeliveryStatus: ChatMessage.DeliveryStatus
        /// Sender of the last message. When set, the group preview prefixes the
        /// body with the sender name ("You:" if `senderId` is the current user,
        /// otherwise the sender's short name). Leave nil for no sender prefix.
        public var lastMessageSenderId: String?
        public var lastMessageSenderName: String?
        /// Unread message count. Drives the unread badge; also required (alongside
        /// `mentionCount`) for the mention badge to appear.
        public var unreadCount: UInt64
        public var mentionCount: UInt64
        public var muted: Bool
        public var pinned: Bool

        public init(
            id: ChannelId,
            subject: String,
            lastMessageText: String? = nil,
            lastMessageIsIncoming: Bool = true,
            lastMessageDeliveryStatus: ChatMessage.DeliveryStatus = .displayed,
            lastMessageSenderId: String? = nil,
            lastMessageSenderName: String? = nil,
            unreadCount: UInt64 = 0,
            mentionCount: UInt64 = 0,
            muted: Bool = false,
            pinned: Bool = false
        ) {
            self.id = id
            self.subject = subject
            self.lastMessageText = lastMessageText
            self.lastMessageIsIncoming = lastMessageIsIncoming
            self.lastMessageDeliveryStatus = lastMessageDeliveryStatus
            self.lastMessageSenderId = lastMessageSenderId
            self.lastMessageSenderName = lastMessageSenderName
            self.unreadCount = unreadCount
            self.mentionCount = mentionCount
            self.muted = muted
            self.pinned = pinned
        }
    }

    /// A declarative description of a single message to seed into a channel for
    /// UI tests of the open-channel (conversation) screen.
    public struct UITestMessageSeed {

        public var id: MessageId
        public var body: String
        /// `true` renders an incoming (left) cell, `false` an outgoing (right) cell.
        public var incoming: Bool
        /// Sender of the message. Set to `SceytChatUIKit.uiTestUserId` for own
        /// (outgoing) messages; leave nil for a message with no attached user.
        public var senderId: String?
        public var senderName: String?
        public var deliveryStatus: ChatMessage.DeliveryStatus
        /// When set to another seeded message's `id`, this message becomes an inline
        /// reply quoting that message (renders the reply preview). The referenced
        /// message must appear earlier in the seeded array.
        public var parentId: MessageId?
        /// Explicit creation date. When nil, messages get sequential dates from a
        /// fixed base day, so the whole conversation shares one date. Set it to
        /// place a message on a different day (e.g. `Date()`), which forces a
        /// date-separator boundary in the message list. Later messages must keep
        /// later dates or the visual order changes.
        public var createdAt: Date?

        public init(
            id: MessageId,
            body: String,
            incoming: Bool = true,
            senderId: String? = nil,
            senderName: String? = nil,
            deliveryStatus: ChatMessage.DeliveryStatus = .displayed,
            parentId: MessageId? = nil,
            createdAt: Date? = nil
        ) {
            self.id = id
            self.body = body
            self.incoming = incoming
            self.senderId = senderId
            self.senderName = senderName
            self.deliveryStatus = deliveryStatus
            self.parentId = parentId
            self.createdAt = createdAt
        }
    }

    /// The fake current-user id used by `startUITestSession`. Match a seed's
    /// `lastMessageSenderId` to this to get a "You:" preview prefix.
    public static let uiTestUserId = "uitest-user"

    /// Marks a fake authenticated session so the app routes straight to the main
    /// flow without a live connection. `SceytChatUIKit.currentUserId` reads this
    /// value (via `UserDefaults`) when the chat client is not connected.
    ///
    /// UI-test only.
    public func startUITestSession(userId: String = SceytChatUIKit.uiTestUserId) {
        UserDefaults.currentUserId = userId
    }

    /// Replaces the local channel store with the given fixtures so the channel
    /// list renders deterministically with no network.
    ///
    /// The channel list is driven solely by a Core Data observer
    /// (`ChannelListViewModel`), so seeded `ChannelDTO`s appear immediately with
    /// no provider/connection. Pass an empty array to exercise the empty list.
    ///
    /// UI-test only.
    public func seedChannelsForUITests(_ seeds: [UITestChannelSeed]) {
        // Wipe first (committed in its own save) so repeated launches are
        // deterministic and `createOrUpdate` never collides with stale rows.
        try? database.syncWrite { context in
            let request = ChannelDTO.fetchRequest()
            let existing = (try? context.fetch(request)) ?? []
            existing.forEach { context.delete($0) }
        }

        guard !seeds.isEmpty else { return }

        let groupType = SceytChatUIKit.shared.config.channelTypesConfig.group
        // A fixed base date keeps ordering stable across runs; later fixtures get
        // newer dates, so they sort above earlier ones (sortingKey is DESC).
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        try? database.syncWrite { context in
            for (index, seed) in seeds.enumerated() {
                let date = baseDate.addingTimeInterval(TimeInterval(index))

                let channel = ChatChannel(
                    id: seed.id,
                    type: groupType,
                    createdAt: date,
                    updatedAt: date,
                    newMessageCount: seed.unreadCount,
                    newMentionCount: seed.mentionCount,
                    muted: seed.muted,
                    pinnedAt: seed.pinned ? date : nil,
                    subject: seed.subject,
                    uri: "uitest-\(seed.id)",
                    // A non-nil role marks the channel as subscribed; the list's
                    // fetch predicate filters out `unsubscribed` channels.
                    userRole: "owner"
                )
                let channelDTO = context.createOrUpdate(channel: channel)

                if let text = seed.lastMessageText {
                    let message = MessageDTO.fetchOrCreate(
                        id: MessageId(seed.id) * 1000 + 1,
                        tid: 0,
                        context: context
                    )
                    message.body = text
                    message.type = "text"
                    message.channelId = Int64(seed.id)
                    message.incoming = seed.lastMessageIsIncoming
                    message.state = 0 // ChatMessage.State.none
                    message.deliveryStatus = Int16(seed.lastMessageDeliveryStatus.intValue)
                    message.createdAt = date.bridgeDate
                    if let senderId = seed.lastMessageSenderId {
                        message.user = context.createOrUpdate(
                            user: ChatUser(id: senderId, firstName: seed.lastMessageSenderName)
                        )
                    }
                    channelDTO.lastMessage = message
                }
            }
        }
    }

    /// Simulates a freshly-arrived message on an existing seeded channel.
    ///
    /// Inserts a new last message dated *now* (newer than any seeded fixture), so
    /// the channel list reorders the row toward the top and refreshes its preview
    /// exactly as a live message would — driven entirely through the Core Data
    /// observer, with no network.
    ///
    /// UI-test only.
    public func receiveUITestMessage(channelId: ChannelId,
                                     text: String,
                                     incoming: Bool = true) {
        try? database.syncWrite { context in
            guard let channelDTO = ChannelDTO.fetch(id: channelId, context: context)
            else { return }
            let now = Date()
            let message = MessageDTO.fetchOrCreate(
                id: MessageId(now.timeIntervalSince1970 * 1000),
                tid: 0,
                context: context
            )
            message.body = text
            message.type = "text"
            message.channelId = Int64(channelId)
            message.incoming = incoming
            message.state = 0 // ChatMessage.State.none
            message.deliveryStatus = Int16(ChatMessage.DeliveryStatus.sent.intValue)
            message.createdAt = now.bridgeDate
            // Newer `lastMessage.createdAt` bumps the channel's `sortingKey` in
            // `ChannelDTO.willSave`, moving the row to the top of its group.
            channelDTO.lastMessage = message
        }
    }

    /// Rewrites the body of an existing message, simulating an in-place update
    /// that changes the cell's height after it is already on screen — the same
    /// list-level effect as a link preview or attachment thumbnail arriving
    /// asynchronously, or a message edit.
    ///
    /// UI-test only.
    public func updateUITestMessageBody(messageId: MessageId, body: String) {
        try? database.syncWrite { context in
            let request = MessageDTO.fetchRequest()
            request.predicate = NSPredicate(format: "id == %lld", Int64(messageId))
            request.fetchLimit = 1
            (try? context.fetch(request))?.first?.body = body
        }
    }

    /// Seeds a deterministic conversation of messages into an existing channel so
    /// the open-channel (`ChannelViewController`) screen renders with no network.
    ///
    /// Messages are dated in ascending order (first element oldest, last newest),
    /// so the mirrored message list shows the last element at the visual bottom.
    /// The channel's `lastMessage` is set to the newest seeded message.
    ///
    /// - Parameters:
    ///   - unreadCount: value for the channel's unread counter.
    ///   - lastDisplayedMessageId: when non-zero, marks the last *read* message so
    ///     the "New messages" separator renders on it. For the separator to show,
    ///     the newest seeded message must be `incoming` and this id must differ
    ///     from it (see `ChannelViewModel.init`).
    ///
    /// UI-test only.
    public func seedMessagesForUITests(
        channelId: ChannelId,
        messages: [UITestMessageSeed],
        unreadCount: UInt64 = 0,
        lastDisplayedMessageId: MessageId = 0
    ) {
        // Clear any messages already in this channel first so repeated launches
        // seed a deterministic conversation.
        try? database.syncWrite { context in
            let request = MessageDTO.fetchRequest()
            request.predicate = NSPredicate(format: "channelId == %lld", Int64(channelId))
            let existing = (try? context.fetch(request)) ?? []
            existing.forEach { context.delete($0) }
        }

        guard !messages.isEmpty else { return }

        // A fixed base date keeps ordering stable across runs; later messages get
        // newer dates so they sort below (visually lower) earlier ones.
        let baseDate = Date(timeIntervalSince1970: 1_700_100_000)

        try? database.syncWrite { context in
            guard let channelDTO = ChannelDTO.fetch(id: channelId, context: context)
            else { return }

            var newestMessage: MessageDTO?
            var created: [MessageId: MessageDTO] = [:]
            for (index, seed) in messages.enumerated() {
                let date = seed.createdAt ?? baseDate.addingTimeInterval(TimeInterval(index))
                let message = MessageDTO.fetchOrCreate(id: seed.id, tid: 0, context: context)
                message.body = seed.body
                message.type = "text"
                message.channelId = Int64(channelId)
                message.incoming = seed.incoming
                message.state = 0 // ChatMessage.State.none
                message.deliveryStatus = Int16(seed.deliveryStatus.intValue)
                message.createdAt = date.bridgeDate
                if let senderId = seed.senderId {
                    message.user = context.createOrUpdate(
                        user: ChatUser(id: senderId, firstName: seed.senderName)
                    )
                }
                // Inline reply: point at an already-created earlier message so the
                // reply preview renders.
                if let parentId = seed.parentId {
                    message.parent = created[parentId]
                }
                created[seed.id] = message
                newestMessage = message
            }
            channelDTO.lastMessage = newestMessage
            channelDTO.newMessageCount = Int64(unreadCount)
            if lastDisplayedMessageId != 0 {
                channelDTO.lastDisplayedMessageId = Int64(lastDisplayedMessageId)
            }
        }
    }
}
#endif
