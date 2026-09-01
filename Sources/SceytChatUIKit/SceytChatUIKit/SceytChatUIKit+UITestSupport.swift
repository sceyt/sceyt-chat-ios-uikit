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
import UIKit
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

    /// One option of a seeded poll (see `UITestPollSeed`).
    public struct UITestPollOptionSeed {

        public var id: String
        public var text: String
        /// Server-side vote count for this option (`votesPerOption`).
        public var voteCount: Int
        /// Seeds a *server-confirmed* own vote on this option (`PollDTO.ownVotes`),
        /// i.e. the state after the current user already voted and the server
        /// acknowledged it — not a pending/optimistic vote.
        public var votedByMe: Bool

        public init(id: String, text: String, voteCount: Int = 0, votedByMe: Bool = false) {
            self.id = id
            self.text = text
            self.voteCount = voteCount
            self.votedByMe = votedByMe
        }
    }

    /// A declarative description of a poll to attach to a seeded message, so the
    /// in-bubble poll view renders with no network. Set `allowMultipleVotes` to
    /// `false` for a single-choice poll — the shape where at most one option may
    /// ever show as voted.
    public struct UITestPollSeed {

        public var id: String
        public var question: String
        /// Options in display order; the array index is the option's row index in
        /// the rendered poll (`sceyt_chat_channel_message_cell_poll_option.<index>`).
        public var options: [UITestPollOptionSeed]
        public var allowMultipleVotes: Bool
        public var anonymous: Bool
        public var allowVoteRetract: Bool
        public var closed: Bool

        public init(id: String,
                    question: String,
                    options: [UITestPollOptionSeed],
                    allowMultipleVotes: Bool = false,
                    anonymous: Bool = true,
                    allowVoteRetract: Bool = true,
                    closed: Bool = false) {
            self.id = id
            self.question = question
            self.options = options
            self.allowMultipleVotes = allowMultipleVotes
            self.anonymous = anonymous
            self.allowVoteRetract = allowVoteRetract
            self.closed = closed
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
        /// When set, the message becomes a poll message (`type == "poll"`) and
        /// renders the in-bubble poll view instead of a text bubble. `body` is
        /// still stored (the real send path puts the question there too).
        public var poll: UITestPollSeed?

        public init(
            id: MessageId,
            body: String,
            incoming: Bool = true,
            senderId: String? = nil,
            senderName: String? = nil,
            deliveryStatus: ChatMessage.DeliveryStatus = .displayed,
            parentId: MessageId? = nil,
            createdAt: Date? = nil,
            poll: UITestPollSeed? = nil
        ) {
            self.id = id
            self.body = body
            self.incoming = incoming
            self.senderId = senderId
            self.senderName = senderName
            self.deliveryStatus = deliveryStatus
            self.parentId = parentId
            self.createdAt = createdAt
            self.poll = poll
        }
    }

    /// The fake current-user id used by `startUITestSession`. Match a seed's
    /// `lastMessageSenderId` to this to get a "You:" preview prefix.
    public static let uiTestUserId = "uitest-user"

    /// The fixed base date `seedMessagesForUITests` assigns to seeds with no
    /// explicit `createdAt`: the message at array index `i` is dated
    /// `uiTestMessageSeedBaseDate + i` seconds. Public so a host app's test
    /// harness can compute dates that land BETWEEN two seeded messages (e.g. a
    /// synced batch that must sort into the middle of the history).
    public static let uiTestMessageSeedBaseDate = Date(timeIntervalSince1970: 1_700_100_000)

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
            // Drafts are keyed by channel id rather than a relationship, so deleting the channel
            // rows does not cascade to them. Without this a draft outlives the wipe and reattaches
            // to the re-seeded channel of the same id, leaking state between test launches.
            existing.forEach { DraftMessageDTO.delete(channelId: ChannelId($0.id), context: context) }
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
    /// - Parameter id: explicit message id. Defaults to a timestamp-derived id;
    ///   pass unique ids when injecting several messages within the same
    ///   millisecond (e.g. a message storm), or `fetchOrCreate` dedupes them
    ///   into one row.
    public func receiveUITestMessage(channelId: ChannelId,
                                     text: String,
                                     incoming: Bool = true,
                                     id: MessageId = 0) {
        try? database.syncWrite { context in
            guard let channelDTO = ChannelDTO.fetch(id: channelId, context: context)
            else { return }
            let now = Date()
            let message = MessageDTO.fetchOrCreate(
                id: id != 0 ? id : MessageId(now.timeIntervalSince1970 * 1000),
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

    /// Marks a channel unread locally, without a network round trip.
    ///
    /// The real `markAs(read:)` goes through the SDK's channel operator and only
    /// persists on success, so it cannot be driven in `--uitest` mode. This
    /// writes the same local state directly, letting UI tests exercise behaviour
    /// that depends on a channel's unread state changing while on screen.
    ///
    /// UI-test only.
    public func markUITestChannelUnread(channelId: ChannelId, newMessageCount: UInt64 = 1) {
        try? database.syncWrite { context in
            guard let channelDTO = ChannelDTO.fetch(id: channelId, context: context)
            else { return }
            channelDTO.unread = true
            channelDTO.newMessageCount = Int64(newMessageCount)
        }
    }

    /// Simulates a *batch* of freshly-arrived messages landing in one database
    /// transaction — the shape a server sync delivers when several messages
    /// arrived while the client was catching up. All rows are inserted in a
    /// single write, so the message observer publishes ONE change event whose
    /// diff contains every message, unlike repeated `receiveUITestMessage`
    /// calls which produce one event each.
    ///
    /// UI-test only.
    /// - Parameters:
    ///   - texts: bodies, oldest first; the last becomes the channel's `lastMessage`.
    ///   - startingId: explicit id of the first message; subsequent ones increment.
    public func receiveUITestMessageBurst(channelId: ChannelId,
                                          texts: [String],
                                          incoming: Bool = true,
                                          startingId: MessageId) {
        guard !texts.isEmpty else { return }
        try? database.syncWrite { context in
            guard let channelDTO = ChannelDTO.fetch(id: channelId, context: context)
            else { return }
            let now = Date()
            var newestMessage: MessageDTO?
            for (index, text) in texts.enumerated() {
                let message = MessageDTO.fetchOrCreate(
                    id: startingId + MessageId(index),
                    tid: 0,
                    context: context
                )
                message.body = text
                message.type = "text"
                message.channelId = Int64(channelId)
                message.incoming = incoming
                message.state = 0 // ChatMessage.State.none
                message.deliveryStatus = Int16(ChatMessage.DeliveryStatus.sent.intValue)
                // Strictly increasing dates keep the visual order deterministic.
                message.createdAt = now.addingTimeInterval(TimeInterval(index) / 1000).bridgeDate
                newestMessage = message
            }
            channelDTO.lastMessage = newestMessage
        }
    }

    /// Inserts a batch of messages into an existing conversation in ONE database
    /// transaction WITHOUT wiping what is already there — the shape of a server
    /// sync page landing after the screen is open. Unlike
    /// `receiveUITestMessageBurst` (always dated *now*, at the newest edge), each
    /// seed's explicit `createdAt`/`id` is honored, so the batch can land in the
    /// MIDDLE of the loaded history — e.g. own messages sent from the Web client
    /// on the same account, which are older than the incoming messages already
    /// on screen and sort above them.
    ///
    /// `channel.lastMessage` is left untouched: a mid-history page is by
    /// definition older than the newest message already in the store.
    ///
    /// Returns whether the write committed — the app-side harness surfaces
    /// this so a test can verify the batch actually landed (and retry) instead
    /// of passing vacuously when a write is dropped.
    ///
    /// UI-test only.
    @discardableResult
    public func insertUITestMessages(channelId: ChannelId,
                                     messages: [UITestMessageSeed]) -> Bool {
        guard !messages.isEmpty else { return false }
        do {
            try insertUITestMessagesThrowing(channelId: channelId, messages: messages)
            return true
        } catch {
            return false
        }
    }

    private func insertUITestMessagesThrowing(channelId: ChannelId,
                                              messages: [UITestMessageSeed]) throws {
        try database.syncWrite { context in
            for seed in messages {
                let message = MessageDTO.fetchOrCreate(id: seed.id, tid: 0, context: context)
                message.body = seed.body
                message.type = "text"
                message.channelId = Int64(channelId)
                message.incoming = seed.incoming
                message.state = 0 // ChatMessage.State.none
                message.deliveryStatus = Int16(seed.deliveryStatus.intValue)
                if let createdAt = seed.createdAt {
                    message.createdAt = createdAt.bridgeDate
                }
                if let senderId = seed.senderId {
                    message.user = context.createOrUpdate(
                        user: ChatUser(id: senderId, firstName: seed.senderName)
                    )
                }
            }
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
        let baseDate = Self.uiTestMessageSeedBaseDate

        try? database.syncWrite { context in
            guard let channelDTO = ChannelDTO.fetch(id: channelId, context: context)
            else { return }

            var newestMessage: MessageDTO?
            var created: [MessageId: MessageDTO] = [:]
            for (index, seed) in messages.enumerated() {
                let date = seed.createdAt ?? baseDate.addingTimeInterval(TimeInterval(index))
                let message = MessageDTO.fetchOrCreate(id: seed.id, tid: 0, context: context)
                message.body = seed.body
                message.type = seed.poll != nil ? "poll" : "text"
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
                if let pollSeed = seed.poll {
                    self.createUITestPoll(pollSeed, on: message, context: context)
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

    // MARK: - Poll seeding (test-only)

    /// Builds the `PollDTO` graph a poll message needs and attaches it to `message`,
    /// mirroring what `MessageDatabaseSession.createOrUpdate(poll:dto:)` writes when
    /// a real poll arrives — options in an ordered set (their order is the rendered
    /// row order), per-option counts in `votesPerOption`, and server-confirmed own
    /// votes in `ownVotes`.
    ///
    /// Any pending (unsent) votes left over from an earlier launch are dropped, so
    /// a seeded poll always starts from the state the seed describes.
    private func createUITestPoll(_ seed: UITestPollSeed,
                                  on message: MessageDTO,
                                  context: NSManagedObjectContext) {
        let timestamp = Int64(Self.uiTestMessageSeedBaseDate.timeIntervalSince1970)

        let pollDTO = PollDTO.fetchOrCreate(id: seed.id, context: context)
        pollDTO.name = seed.question
        pollDTO.pollDescription = ""
        pollDTO.anonymous = seed.anonymous
        pollDTO.allowMultipleVotes = seed.allowMultipleVotes
        pollDTO.allowVoteRetract = seed.allowVoteRetract
        pollDTO.closed = seed.closed
        pollDTO.closedAt = 0
        pollDTO.createdAt = timestamp
        pollDTO.updatedAt = timestamp
        pollDTO.messageTid = message.tid
        pollDTO.message = message

        // A previous launch may have left pending votes on this poll id; they would
        // render as an already-cast optimistic vote.
        (pollDTO.pendingVotes?.allObjects as? [PendingVoteDTO])?.forEach { context.delete($0) }

        let options = pollDTO.mutableOrderedSetValue(forKey: "options")
        options.removeAllObjects()
        var counts: [String: NSNumber] = [:]
        for optionSeed in seed.options {
            let optionDTO = PollOptionDTO.fetchOrCreate(
                id: optionSeed.id,
                pollId: seed.id,
                context: context
            )
            optionDTO.name = optionSeed.text
            optionDTO.poll = pollDTO
            options.add(optionDTO)
            counts[optionSeed.id] = NSNumber(value: optionSeed.voteCount)
        }
        pollDTO.votesPerOption = counts as NSDictionary

        let ownVotes = pollDTO.mutableOrderedSetValue(forKey: "ownVotes")
        ownVotes.removeAllObjects()
        if let currentUserId = SceytChatUIKit.shared.currentUserId, !currentUserId.isEmpty {
            for optionSeed in seed.options where optionSeed.votedByMe {
                let voteDTO = PollVoteDTO.fetchOrCreate(
                    optionId: optionSeed.id,
                    userId: currentUserId,
                    pollId: seed.id,
                    context: context
                )
                voteDTO.createdAt = timestamp
                voteDTO.user = context.createOrUpdate(
                    user: ChatUser(id: currentUserId, firstName: "Me")
                )
                voteDTO.ownPollDetails = pollDTO
                ownVotes.add(voteDTO)
            }
        }

        message.poll = pollDTO
    }

    // MARK: - Poll voting (test-only)

    /// When `true`, `ChannelViewModel.addPollVote` / `deletePollVote` release their
    /// in-flight guard as soon as the pending-vote row is stored, instead of when
    /// the server round trip returns.
    ///
    /// UI-test mode never connects, so that round trip never completes and the
    /// guard would swallow every tap after the first — which makes a *changed*
    /// vote impossible to drive. With this on, the app behaves as it does when the
    /// first request has already come back (offline error or no-op ack): the
    /// pending row stays in the database and the next tap is accepted.
    ///
    /// UI-test only.
    public static var uiTestPollVotesCompleteLocally = false

    /// Fires poll-option taps on the poll message currently on screen in the open
    /// conversation, `gapMs` milliseconds apart, through the same
    /// `ChannelViewController.didTapPollOption` entry point a real tap reaches — so
    /// the in-flight guard, the optimistic update notification and the cell's
    /// animated refresh all run exactly as they do for a user.
    ///
    /// XCUITest cannot reliably deliver two taps inside the sub-second window a
    /// "quickly change my vote" gesture spans (it waits for app quiescence between
    /// events, and the poll cell animates on every vote), so tests drive the
    /// sequence from here instead.
    ///
    /// `completion` reports how many taps were actually dispatched: a test asserts
    /// on that first, so a swallowed tap surfaces as a harness failure instead of
    /// letting the real assertion pass vacuously.
    ///
    /// UI-test only.
    public func performUITestPollVotes(optionIndexes: [Int],
                                       gapMs: Int,
                                       completion: @escaping (Int) -> Void) {
        var dispatched = 0

        func fire(_ remaining: ArraySlice<Int>) {
            guard let index = remaining.first else {
                completion(dispatched)
                return
            }
            if tapUITestPollOption(at: index) {
                dispatched += 1
            }
            let rest = remaining.dropFirst()
            guard !rest.isEmpty else {
                completion(dispatched)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(gapMs)) {
                fire(rest)
            }
        }

        fire(optionIndexes[...])
    }

    /// Taps one option of the visible poll message. Returns `false` when there is
    /// nothing to tap (no open conversation, no poll on screen, bad index) — the
    /// caller reports that count so a test never mistakes "nothing happened" for
    /// "the app behaved correctly".
    private func tapUITestPollOption(at index: Int) -> Bool {
        guard let viewController = uiTestChannelViewController(),
              let cell = viewController.collectionView.visibleCells
                  .compactMap({ $0 as? MessageCell })
                  .first(where: { $0.data?.message.poll != nil }),
              let layoutModel = cell.data,
              // The poll view model the cell currently renders — the same value a
              // real tap hands to the view controller, pending votes included.
              let pollViewModel = cell.pollView.pollViewModel,
              index >= 0, index < pollViewModel.options.count
        else { return false }

        viewController.didTapPollOption(
            layoutModel: layoutModel,
            optionIndex: index,
            pollViewModel: pollViewModel
        )
        return true
    }

    /// The `ChannelViewController` currently in the window hierarchy, if any.
    private func uiTestChannelViewController() -> ChannelViewController? {
        func find(_ viewController: UIViewController) -> ChannelViewController? {
            if let channel = viewController as? ChannelViewController { return channel }
            if let presented = viewController.presentedViewController,
               let found = find(presented) {
                return found
            }
            if let navigation = viewController as? UINavigationController {
                for child in navigation.viewControllers.reversed() {
                    if let found = find(child) { return found }
                }
            }
            for child in viewController.children {
                if let found = find(child) { return found }
            }
            return nil
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .compactMap { $0.rootViewController.flatMap(find) }
            .first
    }
}
#endif
