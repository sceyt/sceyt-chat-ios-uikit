//
//  UITestSupport.swift
//  SceytDemoApp
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import UIKit
import SceytChatUIKit

/// Drives the deterministic "UI test" launch mode.
///
/// When the app is launched with `--uitest`, the live login/connection is skipped
/// and a fixed set of channels is seeded into the local database, so XCUITests can
/// drive the channel list with no network. Add `--uitest-empty` to seed nothing
/// and exercise the empty list. Add `--uitest-inject` to expose the message
/// injector buttons used by the reorder/preview test.
enum UITestSupport {

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest")
    }

    private static var isEmpty: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-empty")
    }

    static var isInjectionEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-inject")
    }

    /// Seeds a single channel with a rich message history for the open-channel
    /// (`ChannelViewController`) UI tests. Add `--uitest-conversation-unread` to
    /// also mark unread messages so the "New messages" separator renders.
    static var isConversation: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-conversation")
    }

    private static var isConversationUnread: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-conversation-unread")
    }

    /// `--uitest-conversation-unread-count=N` — seeds the conversation with the
    /// standard history up to the last-read message (index 16) plus exactly N
    /// trailing *incoming* unread messages (ids 16+1…16+N), i.e. a realistic
    /// "N new messages" state. Implies conversation mode; overrides the fixed
    /// 3-unread fixture of `--uitest-conversation-unread`.
    private static var conversationUnreadCountOverride: Int? {
        launchArgumentValue("--uitest-conversation-unread-count")
    }

    /// `--uitest-inject-on-open=<ms>` — auto-injects one incoming message this
    /// many milliseconds after the conversation screen *starts opening* (the
    /// push transition begins). 0 lands the message mid-transition, before the
    /// initial scroll position settles; ~1500+ lands after the screen is idle.
    private static var injectOnOpenDelayMs: Int? {
        launchArgumentValue("--uitest-inject-on-open")
    }

    /// `--uitest-conversation-unread-long` — makes the parametrized unread tail
    /// use long multi-line bodies instead of one-liners, so the newest cells are
    /// several lines tall. Exposes initial-scroll positions computed from
    /// estimated (single-line) cell heights.
    private static var isConversationUnreadLong: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-conversation-unread-long")
    }

    /// `--uitest-conversation-unread-recent` — dates the parametrized unread tail
    /// *now* while the history keeps its fixed old day, so a date-separator
    /// boundary renders between the last-read message and the unread messages —
    /// as in any real channel where the new messages arrive days after the old
    /// ones. Exposes open positions that miss the separator's height.
    private static var isConversationUnreadRecent: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-conversation-unread-recent")
    }

    /// `--uitest-grow-newest-on-open=<ms>` — this many milliseconds after the
    /// conversation screen starts opening, rewrites the newest seeded message's
    /// body to a long multi-line text. The bottom cell grows *in place* after
    /// the initial scroll — the list-level effect of a link preview or
    /// attachment thumbnail loading asynchronously, or of a message edit.
    /// Requires `--uitest-conversation-unread-count`.
    private static var growNewestOnOpenDelayMs: Int? {
        launchArgumentValue("--uitest-grow-newest-on-open")
    }

    /// `--uitest-inject-burst-on-open=<ms>x<count>` — `<ms>` milliseconds after
    /// the conversation screen starts opening, inserts `count` incoming messages
    /// in ONE database transaction — the shape a server sync delivers when
    /// several messages arrived while the client was catching up. Unlike
    /// `--uitest-inject-on-open`, the message observer publishes a single change
    /// event whose diff carries every message at once (a multi-insert batch).
    /// Bodies are long multi-line texts (`conversationBurstText`) so the batch
    /// is tall enough to push the "New messages" separator a full screen away
    /// from the bottom.
    private static var injectBurstOnOpenSpec: (delayMs: Int, count: Int)? {
        let prefix = "--uitest-inject-burst-on-open="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })
        else { return nil }
        let parts = argument.dropFirst(prefix.count).split(separator: "x")
        guard parts.count == 2,
              let delayMs = Int(parts[0]), let count = Int(parts[1]),
              delayMs >= 0, count > 0
        else { return nil }
        return (delayMs, count)
    }

    /// `--uitest-inject-on-keyboard=<ms>` — injects one incoming message `<ms>`
    /// milliseconds after the keyboard starts presenting (the first
    /// `keyboardWillShow` after launch). The keyboard's slide-up runs ~250ms and
    /// animates the list's content insets with it, so a small delay lands the
    /// insert inside that animation window — while the offset-vs-inset "am I at
    /// the bottom" check is transiently unreliable.
    private static var injectOnKeyboardDelayMs: Int? {
        launchArgumentValue("--uitest-inject-on-keyboard")
    }

    /// `--uitest-restart-observer-on-open=<ms>` — `<ms>` after the conversation
    /// screen starts opening, restarts its message observer exactly the way
    /// `ChannelViewModel.createAndSendUserMessage` does when the cached tail
    /// lags behind `channel.lastMessage` (routine during rapid receive/ACK
    /// traffic). The restart re-delivers an `isInitial` change event
    /// mid-session — the trigger that used to re-anchor the viewport to the
    /// stale unread separator — without the racy timing of the real desync.
    private static var restartObserverOnOpenDelayMs: Int? {
        launchArgumentValue("--uitest-restart-observer-on-open")
    }

    /// `--uitest-web-sync-button=<count>[xrestart]` — installs a floating button
    /// (`uitest.injectWebSync`) that, on tap, inserts `count` OUTGOING messages
    /// in ONE database transaction, dated in the gap between the last-read
    /// message and the unread incoming tail — own messages the same account
    /// sent from the Web client, delivered late by a server sync. They sort
    /// ABOVE the received messages already on screen, so the batch lands in the
    /// middle of the loaded history, not at the newest edge. With the
    /// `xrestart` suffix, the tap also restarts the conversation's message
    /// observer right after the insert — the window recalculation the real
    /// sync pipeline performs, which re-delivers an `isInitial` change event.
    private static var webSyncButtonSpec: (count: Int, restart: Bool)? {
        let prefix = "--uitest-web-sync-button="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })
        else { return nil }
        let parts = argument.dropFirst(prefix.count).split(separator: "x")
        guard let first = parts.first, let count = Int(first), count > 0 else { return nil }
        return (count, parts.count == 2 && parts[1] == "restart")
    }

    /// `--uitest-web-sync-on-open=<ms>x<count>[xrestart]` — the same web-sync
    /// insert as `--uitest-web-sync-button`, fired automatically `<ms>`
    /// milliseconds after the conversation screen starts opening (see
    /// `scheduleOnConversationOpen` for what 0 vs ~1500 means).
    private static var webSyncOnOpenSpec: (delayMs: Int, count: Int, restart: Bool)? {
        let prefix = "--uitest-web-sync-on-open="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })
        else { return nil }
        let parts = argument.dropFirst(prefix.count).split(separator: "x")
        guard parts.count >= 2,
              let delayMs = Int(parts[0]), let count = Int(parts[1]),
              delayMs >= 0, count > 0
        else { return nil }
        return (delayMs, count, parts.count == 3 && parts[2] == "restart")
    }

    /// `--uitest-poll[=multiple]` — seeds a short conversation whose newest
    /// message is a poll, so the in-bubble poll view is on screen the moment the
    /// channel opens. Without the `=multiple` suffix the poll is single-choice
    /// (`allowMultipleVotes == false`), i.e. at most one option may ever render as
    /// voted. Implies conversation mode and, since UI-test mode never connects,
    /// switches poll-vote requests to completing locally
    /// (`SceytChatUIKit.uiTestPollVotesCompleteLocally`).
    private static var isPoll: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--uitest-poll")
            || arguments.contains { $0.hasPrefix("--uitest-poll=") }
    }

    private static var pollAllowsMultipleVotes: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitest-poll=multiple")
    }

    /// `--uitest-poll-double-vote=<gapMs>` — installs a floating button
    /// (`uitest.pollDoubleVote`) that, on tap, votes for the FIRST poll option and
    /// then, `gapMs` milliseconds later, for the SECOND one: the "tap option 1,
    /// immediately change to option 2" gesture, at a gap XCUITest cannot deliver
    /// itself. On commit the button stamps the number of dispatched votes into its
    /// `accessibilityValue`, so the test can tell a real run from a swallowed tap.
    private static var pollDoubleVoteGapMs: Int? {
        launchArgumentValue("--uitest-poll-double-vote")
    }

    /// `--uitest-web-sync-seeded=<count>` — bakes the Web-sent outgoing run
    /// into the seeded conversation itself, between the last-read message and
    /// the unread incoming tail — a cold start whose server sync completed
    /// BEFORE the channel was opened. Requires
    /// `--uitest-conversation-unread-count`.
    private static var webSyncSeededCount: Int? {
        launchArgumentValue("--uitest-web-sync-seeded")
    }

    /// `--uitest-message-storm=<pairs>x<intervalMs>[x<startMs>]` — `startMs`
    /// (default 1500) after the conversation screen starts opening, fires
    /// `pairs` timer ticks every `intervalMs`; each tick inserts one outgoing
    /// and one incoming message back-to-back through the same DB→observer
    /// pipeline live traffic uses. E.g. `20x300` = 20 sent + 20 received
    /// messages at a 0.3s cadence, saturating the insert-batch queue while the
    /// user rests at the bottom. A small `startMs` (e.g. 200) makes the storm
    /// the first traffic the open screen sees — an already-busy channel.
    private static var messageStormSpec: (pairs: Int, intervalMs: Int, startMs: Int)? {
        let prefix = "--uitest-message-storm="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })
        else { return nil }
        let parts = argument.dropFirst(prefix.count).split(separator: "x")
        guard parts.count == 2 || parts.count == 3,
              let pairs = Int(parts[0]), let intervalMs = Int(parts[1]),
              pairs > 0, intervalMs > 0
        else { return nil }
        let startMs = parts.count == 3 ? Int(parts[2]) ?? 1500 : 1500
        return (pairs, intervalMs, startMs)
    }

    /// The integer value of a `<name>=<value>` launch argument, if present.
    private static func launchArgumentValue(_ name: String) -> Int? {
        let prefix = name + "="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) })
        else { return nil }
        return Int(argument.dropFirst(prefix.count))
    }

    /// Call as early as possible at launch, right after `configureSceytChatUIKit()`.
    static func bootstrapIfNeeded() {
        guard isActive else { return }
        #if DEBUG
        SceytChatUIKit.shared.startUITestSession()
        if isPoll {
            // No live connection here, so a vote request never comes back; without
            // this the in-flight guard would swallow every tap after the first and
            // a *changed* vote could not be driven at all.
            SceytChatUIKit.uiTestPollVotesCompleteLocally = true
            seedPollConversation()
            if let gapMs = pollDoubleVoteGapMs {
                installFloatingPollDoubleVoteInjector(gapMs: gapMs)
            }
        } else if isConversation || isConversationUnread || conversationUnreadCountOverride != nil {
            seedConversation()
            if isInjectionEnabled {
                installFloatingConversationInjector()
            }
            if let delayMs = injectOnOpenDelayMs {
                scheduleInjectionOnConversationOpen(afterMs: delayMs)
            }
            if let delayMs = growNewestOnOpenDelayMs,
               let unreadCount = conversationUnreadCountOverride {
                scheduleOnConversationOpen(afterMs: delayMs) {
                    SceytChatUIKit.shared.updateUITestMessageBody(
                        messageId: conversationMessageId(UInt64(16 + unreadCount)),
                        body: conversationGrownBodyText
                    )
                }
            }
            if let burst = injectBurstOnOpenSpec {
                scheduleOnConversationOpen(afterMs: burst.delayMs) {
                    SceytChatUIKit.shared.receiveUITestMessageBurst(
                        channelId: conversationChannelId,
                        texts: (1...burst.count).map(conversationBurstText),
                        startingId: 3_000_000)
                }
            }
            if let delayMs = injectOnKeyboardDelayMs {
                scheduleInjectionOnKeyboardShow(afterMs: delayMs)
            }
            if let delayMs = restartObserverOnOpenDelayMs {
                scheduleOnConversationOpen(afterMs: delayMs) {
                    restartConversationMessageObserver()
                }
            }
            if let storm = messageStormSpec {
                scheduleOnConversationOpen(afterMs: storm.startMs) {
                    startMessageStorm(pairs: storm.pairs, intervalMs: storm.intervalMs)
                }
            }
            if webSyncButtonSpec != nil {
                installFloatingWebSyncInjector()
            }
            if let webSync = webSyncOnOpenSpec {
                scheduleOnConversationOpen(afterMs: webSync.delayMs) {
                    performWebSync(count: webSync.count, restart: webSync.restart)
                }
            }
        } else {
            SceytChatUIKit.shared.seedChannelsForUITests(isEmpty ? [] : fixtures)
        }
        #endif
    }

    #if DEBUG
    /// One channel per cell state the UI tests assert on. Ids are fixed so a test
    /// can address a row directly via `sceyt_chat_channel_list_cell.<id>`.
    private static var fixtures: [SceytChatUIKit.UITestChannelSeed] {
        [
            .init(id: 1,
                  subject: "Design Team",
                  lastMessageText: "Let's finalize the mockups today.",
                  lastMessageSenderId: "alice",
                  lastMessageSenderName: "Alice"),
            .init(id: 2,
                  subject: "Marketing",
                  lastMessageText: "Campaign is live!",
                  unreadCount: 5),
            .init(id: 3,
                  subject: "Random",
                  lastMessageText: "Anyone up for lunch?",
                  muted: true),
            .init(id: 4,
                  subject: "Announcements",
                  lastMessageText: "Office closed on Friday.",
                  pinned: true),
            .init(id: 5,
                  subject: "Project X",
                  lastMessageText: "Please review the PR.",
                  unreadCount: 2,
                  mentionCount: 1),
            .init(id: 6,
                  subject: "Product",
                  lastMessageText: "Shipped the build.",
                  lastMessageIsIncoming: false,
                  lastMessageDeliveryStatus: .displayed,
                  lastMessageSenderId: SceytChatUIKit.uiTestUserId,
                  lastMessageSenderName: "Me")
        ]
    }

    // MARK: - Conversation seeding (test-only, gated behind --uitest-conversation)

    /// The channel opened by the `ChannelViewController` UI tests.
    static let conversationChannelId: UInt64 = 100
    static let conversationSubject = "UITest Chat"

    /// Distinct, matchable message bodies the conversation tests assert on.
    static let conversationFirstText = "Start of the conversation"
    static let conversationLastReadText = "This is the last read message"
    static let conversationOutgoingText = "My outgoing reply"
    static let conversationLastText = "This is the newest message"

    private static func conversationMessageId(_ index: UInt64) -> UInt64 {
        conversationChannelId * 10_000 + index
    }

    /// A deterministic ~19-message conversation: the first message sits at the top
    /// (older, needs scrolling up), the last at the visual bottom. `conversationLastReadText`
    /// (index 16) is the unread-separator anchor and `conversationLastText`
    /// (index 19, incoming) is the newest message.
    private static var conversationMessages: [SceytChatUIKit.UITestMessageSeed] {
        let me = SceytChatUIKit.uiTestUserId
        var messages: [SceytChatUIKit.UITestMessageSeed] = [
            .init(id: conversationMessageId(1),
                  body: conversationFirstText,
                  incoming: true, senderId: "bob", senderName: "Bob")
        ]
        // Filler so the list is comfortably scrollable on a phone.
        for n in 2...15 {
            let incoming = !n.isMultiple(of: 2)
            messages.append(.init(
                id: conversationMessageId(UInt64(n)),
                body: "Message number \(n)",
                incoming: incoming,
                senderId: incoming ? "bob" : me,
                senderName: incoming ? "Bob" : "Me"))
        }
        messages.append(contentsOf: [
            .init(id: conversationMessageId(16),
                  body: conversationLastReadText,
                  incoming: true, senderId: "bob", senderName: "Bob"),
            .init(id: conversationMessageId(17),
                  body: "New message after read",
                  incoming: true, senderId: "bob", senderName: "Bob"),
            // Inline reply quoting the very first message (which is off-screen at
            // the top on open), so tapping the reply preview scrolls up to it.
            .init(id: conversationMessageId(18),
                  body: conversationOutgoingText,
                  incoming: false, senderId: me, senderName: "Me",
                  parentId: conversationMessageId(1)),
            // Newest message; incoming so the unread separator can render.
            .init(id: conversationMessageId(19),
                  body: conversationLastText,
                  incoming: true, senderId: "bob", senderName: "Bob")
        ])
        return messages
    }

    /// Body of the `n`-th message in the parametrized unread tail seeded by
    /// `--uitest-conversation-unread-count=N`. Mirrored in the UI-test bundle
    /// (`ChannelScreen.Conversation.unreadTailText`).
    static func conversationUnreadTailText(_ n: Int) -> String { "Unread incoming \(n)" }

    /// Long multi-line variant of the tail body, used with
    /// `--uitest-conversation-unread-long`. Deliberately long enough to wrap
    /// across several lines on any phone.
    static func conversationUnreadTailLongText(_ n: Int) -> String {
        "Unread incoming \(n) — this body is deliberately long so the bubble wraps "
            + "across several lines and the cell ends up much taller than a "
            + "single-line estimate would suggest, which is what the open-position "
            + "tests are probing."
    }

    private static func seedConversation() {
        SceytChatUIKit.shared.seedChannelsForUITests([
            .init(id: conversationChannelId, subject: conversationSubject)
        ])
        if let unreadCount = conversationUnreadCountOverride, unreadCount > 0 {
            // Parametrized variant: history up to the last-read message
            // (indices 1–16), then exactly `unreadCount` incoming unread
            // messages — the "N new messages" state the open-position tests probe.
            var messages = Array(conversationMessages.prefix(16))
            // Optionally bake in the Web-sent outgoing run (explicit dates in
            // the gap between the last-read message and the unread tail).
            if let seededWebCount = webSyncSeededCount, seededWebCount > 0 {
                messages.append(contentsOf: webSyncSeeds(count: seededWebCount))
            }
            for n in 1...unreadCount {
                messages.append(.init(
                    id: conversationMessageId(UInt64(16 + n)),
                    body: isConversationUnreadLong
                        ? conversationUnreadTailLongText(n)
                        : conversationUnreadTailText(n),
                    incoming: true, senderId: "bob", senderName: "Bob",
                    // "Recent" tail: dated moments ago (today), a different day
                    // from the fixed 2023 history — forces a date separator.
                    createdAt: isConversationUnreadRecent
                        ? Date().addingTimeInterval(TimeInterval(n) - 60)
                        : nil))
            }
            SceytChatUIKit.shared.seedMessagesForUITests(
                channelId: conversationChannelId,
                messages: messages,
                unreadCount: UInt64(unreadCount),
                lastDisplayedMessageId: conversationMessageId(16)
            )
        } else {
            SceytChatUIKit.shared.seedMessagesForUITests(
                channelId: conversationChannelId,
                messages: conversationMessages,
                // 3 unread messages (indices 17–19) sitting after the last read one.
                unreadCount: isConversationUnread ? 3 : 0,
                lastDisplayedMessageId: isConversationUnread ? conversationMessageId(16) : 0
            )
        }
    }

    // MARK: - Poll conversation (test-only, gated behind --uitest-poll)

    static let pollId = "uitest-poll-1"
    static let pollQuestion = "Which option do you pick?"
    /// Option bodies in row order. Mirrored in the UI-test bundle
    /// (`ChannelScreen.Conversation.pollOptionTexts`).
    static let pollOptionTexts = ["First option", "Second option", "Third option"]
    /// The poll message: newest in the seeded conversation, so it is on screen the
    /// moment the channel opens.
    static var pollMessageId: UInt64 { conversationMessageId(20) }

    static func pollOptionId(_ index: Int) -> String { "uitest-poll-option-\(index)" }

    /// A short history plus a poll as the newest message. The poll starts with no
    /// votes at all, so a test can watch the very first vote land — and, for a
    /// single-choice poll, watch it *move* when the user changes their mind.
    private static func seedPollConversation() {
        SceytChatUIKit.shared.seedChannelsForUITests([
            .init(id: conversationChannelId, subject: conversationSubject)
        ])
        var messages = Array(conversationMessages.prefix(5))
        messages.append(
            .init(id: pollMessageId,
                  body: pollQuestion,
                  incoming: true,
                  senderId: "bob",
                  senderName: "Bob",
                  poll: .init(
                      id: pollId,
                      question: pollQuestion,
                      options: pollOptionTexts.enumerated().map { index, text in
                          .init(id: pollOptionId(index), text: text)
                      },
                      allowMultipleVotes: pollAllowsMultipleVotes,
                      // Anonymous, so no voter avatars render and the whole option
                      // row votes on tap — the poll's vote state is the only thing
                      // the test has to reason about.
                      anonymous: true))
        )
        SceytChatUIKit.shared.seedMessagesForUITests(
            channelId: conversationChannelId,
            messages: messages
        )
    }

    /// Button-tap entry point for `--uitest-poll-double-vote=<gapMs>`: votes for the
    /// first option, then for the second one `gapMs` later, and stamps how many of
    /// the two votes were actually dispatched into the button's accessibility value
    /// so the test can reject a vacuous run.
    static func performPollDoubleVoteFromButton() {
        guard let gapMs = pollDoubleVoteGapMs else { return }
        SceytChatUIKit.shared.performUITestPollVotes(
            optionIndexes: [0, 1],
            gapMs: gapMs
        ) { dispatched in
            findWindowButton(identifier: "uitest.pollDoubleVote")?
                .accessibilityValue = "\(dispatched)"
        }
    }

    /// A third floating, window-level button (below the web-sync injector's spot)
    /// that fires the rapid vote change. Present only with
    /// `--uitest-poll-double-vote=<gapMs>`.
    private static func installFloatingPollDoubleVoteInjector(gapMs: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first
            else { return }
            let button = UIButton(type: .system)
            button.setTitle("⇄", for: .normal)
            button.accessibilityIdentifier = "uitest.pollDoubleVote"
            button.backgroundColor = .systemPink
            button.frame = CGRect(x: 0, y: window.safeAreaInsets.top + 56, width: 44, height: 44)
            button.layer.zPosition = .greatestFiniteMagnitude
            button.addTarget(UITestMessageInjector.shared,
                             action: #selector(UITestMessageInjector.pollDoubleVote),
                             for: .touchUpInside)
            window.addSubview(button)
        }
    }

    // MARK: - Message injection (test-only, gated behind --uitest-inject)

    /// The channel the injector targets. In conversation mode it is the open
    /// conversation itself (so tests can simulate receiving a message while the
    /// channel screen is up); in list mode it is id 1 "Design Team", the oldest
    /// seeded channel, which starts at the bottom of the list.
    static var injectTargetChannelId: UInt64 {
        (isConversation || isConversationUnread || conversationUnreadCountOverride != nil)
            ? conversationChannelId : 1
    }
    static let injectedShortText = "Quick hello"
    static let injectedLongText = "This is a deliberately long preview message that should wrap across two lines in the channel list to verify the two-line layout."

    /// Adds a floating, window-level button that injects an incoming message into
    /// the conversation channel. Unlike the nav-bar injector below (used by the
    /// channel-list tests), this stays reachable while the conversation screen is
    /// pushed. Placed at the left edge below the nav bar, small enough not to
    /// cover any message-cell hit point (cell centers are near the screen middle).
    /// Present only with `--uitest-inject` in conversation mode.
    private static func installFloatingConversationInjector() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first
            else { return }
            let button = UIButton(type: .system)
            button.setTitle("⇩", for: .normal)
            button.accessibilityIdentifier = "uitest.injectIncoming"
            button.backgroundColor = .systemYellow
            button.frame = CGRect(x: 0, y: window.safeAreaInsets.top + 56, width: 44, height: 44)
            button.layer.zPosition = .greatestFiniteMagnitude
            button.addTarget(UITestMessageInjector.shared,
                             action: #selector(UITestMessageInjector.injectShort),
                             for: .touchUpInside)
            window.addSubview(button)
        }
    }

    /// The multi-line body `--uitest-grow-newest-on-open` rewrites the newest
    /// message to. Mirrored in the UI-test bundle
    /// (`ChannelScreen.Conversation.grownBodyText`).
    static let conversationGrownBodyText =
        "This body replaced the original one after the screen opened and is "
            + "deliberately long enough to wrap across several lines, so the "
            + "bottom-most cell grows in place well after the initial scroll "
            + "position has settled."

    /// Auto-injects one incoming message `delayMs` after the conversation screen
    /// starts opening. Present only with `--uitest-inject-on-open=<ms>` in
    /// conversation mode.
    private static func scheduleInjectionOnConversationOpen(afterMs delayMs: Int) {
        scheduleOnConversationOpen(afterMs: delayMs) {
            UITestMessageInjector.shared.injectShort()
        }
    }

    /// Body of the `n`-th message in a `--uitest-inject-burst-on-open` batch.
    /// Deliberately long enough to wrap across several lines, so a handful of
    /// burst messages outgrow a phone screen. Mirrored in the UI-test bundle
    /// (`ChannelScreen.Conversation.burstText`).
    static func conversationBurstText(_ n: Int) -> String {
        "Burst incoming \(n) — this body is deliberately long so the bubble wraps "
            + "across several lines and the whole batch is tall enough to push "
            + "the New-messages separator a full screen away from the bottom."
    }

    /// Injects one incoming message `delayMs` after the first keyboard
    /// presentation begins. Present only with `--uitest-inject-on-keyboard=<ms>`
    /// in conversation mode.
    private static func scheduleInjectionOnKeyboardShow(afterMs delayMs: Int) {
        final class TokenHolder { var token: NSObjectProtocol? }
        let holder = TokenHolder()
        holder.token = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            if let token = holder.token {
                NotificationCenter.default.removeObserver(token)
                holder.token = nil
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                UITestMessageInjector.shared.injectShort()
            }
        }
    }

    /// Bodies of the storm messages (`--uitest-message-storm`). Mirrored in the
    /// UI-test bundle (`ChannelScreen.Conversation.stormSentText/stormReceivedText`).
    static func conversationStormSentText(_ n: Int) -> String { "Storm sent \(n)" }
    static func conversationStormReceivedText(_ n: Int) -> String { "Storm received \(n)" }

    // MARK: - Web-sync injection (same account active on Web)

    /// Body of the `n`-th web-sent message a web-sync insert delivers.
    /// Deliberately long enough to wrap across several lines, so a handful of
    /// them stack taller than a phone screen — a viewport that jumps onto the
    /// block cannot be mistaken for a small settle. Mirrored in the UI-test
    /// bundle (`ChannelScreen.Conversation.webSyncText`).
    static func conversationWebSyncText(_ n: Int) -> String {
        "Sent from Web \(n) — this message was written on the Web client of the "
            + "same account before the incoming messages arrived, and it reaches "
            + "this device only later, through a server sync, so it must slot in "
            + "ABOVE the received messages without moving the viewport."
    }

    /// The web-sent batch: OUTGOING messages (the same account, other device),
    /// dated in the open gap between the last-read message (seed index 15 →
    /// base+15s) and the first unread incoming one (index 16 → base+16s), so
    /// they sort into the middle of the history — above the received block the
    /// screen opened on. Sub-second steps keep the whole batch inside the gap
    /// (the message list orders by `createdAt, id` ascending).
    private static func webSyncSeeds(count: Int) -> [SceytChatUIKit.UITestMessageSeed] {
        let base = SceytChatUIKit.uiTestMessageSeedBaseDate
        return (1...min(count, 40)).map { n in
            .init(id: 4_000_000 + UInt64(n),
                  body: conversationWebSyncText(n),
                  incoming: false,
                  senderId: SceytChatUIKit.uiTestUserId,
                  senderName: "Me",
                  deliveryStatus: .sent,
                  createdAt: base.addingTimeInterval(15.0 + Double(n) * 0.02))
        }
    }

    /// Button-tap entry point: reads the launch-argument spec so the injector
    /// target needs no stored state. On a committed insert, stamps the injected
    /// count into the button's accessibility value — the test polls that value
    /// to verify the batch really landed (and re-taps otherwise), instead of
    /// passing vacuously when a write is dropped or a tap misses.
    static func performWebSyncFromButton() {
        guard let spec = webSyncButtonSpec else { return }
        if performWebSync(count: spec.count, restart: spec.restart) {
            findWindowButton(identifier: "uitest.injectWebSync")?
                .accessibilityValue = "\(spec.count)"
        }
    }

    /// Inserts the web-sent batch in one transaction; with `restart`, follows up
    /// with the observer-window recalculation the real sync pipeline performs
    /// after storing a page (re-delivers an `isInitial` change event). The small
    /// delay lets the insert's own diff apply first — the real recalc also runs
    /// only after the store completes. Returns whether the insert committed
    /// (the restart is skipped for a dropped write — there is nothing to sync).
    @discardableResult
    static func performWebSync(count: Int, restart: Bool) -> Bool {
        let landed = SceytChatUIKit.shared.insertUITestMessages(
            channelId: conversationChannelId,
            messages: webSyncSeeds(count: count))
        if landed, restart {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                restartConversationMessageObserver()
            }
        }
        return landed
    }

    /// A window-level floating button previously installed by this harness.
    private static func findWindowButton(identifier: String) -> UIButton? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .flatMap { $0.subviews }
            .compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == identifier }
    }

    /// Adds a second floating, window-level button (below the incoming-message
    /// injector's spot) that fires the web-sync insert on tap — so a test can
    /// sequence it exactly after a user gesture (the reported repro: the user
    /// drags a little, THEN the web-sent messages arrive). Present only with
    /// `--uitest-web-sync-button=<count>[xrestart]` in conversation mode.
    private static func installFloatingWebSyncInjector() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first
            else { return }
            let button = UIButton(type: .system)
            button.setTitle("⇵", for: .normal)
            button.accessibilityIdentifier = "uitest.injectWebSync"
            button.backgroundColor = .systemTeal
            button.frame = CGRect(x: 0, y: window.safeAreaInsets.top + 108, width: 44, height: 44)
            button.layer.zPosition = .greatestFiniteMagnitude
            button.addTarget(UITestMessageInjector.shared,
                             action: #selector(UITestMessageInjector.injectWebSync),
                             for: .touchUpInside)
            window.addSubview(button)
        }
    }

    /// Fires `pairs` ticks every `intervalMs`, each inserting one outgoing and
    /// one incoming message back-to-back. Ids are explicit, unique, and
    /// increasing (well clear of the seeded range at channelId * 10_000 + index),
    /// because two timestamp-derived ids within one millisecond would dedupe.
    private static func startMessageStorm(pairs: Int, intervalMs: Int) {
        var tick = 0
        let timer = Timer(timeInterval: Double(intervalMs) / 1000, repeats: true) { timer in
            tick += 1
            let n = tick
            SceytChatUIKit.shared.receiveUITestMessage(
                channelId: conversationChannelId,
                text: conversationStormSentText(n),
                incoming: false,
                id: UInt64(2_000_000 + 2 * n))
            SceytChatUIKit.shared.receiveUITestMessage(
                channelId: conversationChannelId,
                text: conversationStormReceivedText(n),
                incoming: true,
                id: UInt64(2_000_000 + 2 * n + 1))
            if tick >= pairs {
                timer.invalidate()
            }
        }
        // `.common` so ticks keep firing during scrolling/animations.
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Restarts the open conversation's message observer with the same call
    /// `ChannelViewModel.createAndSendUserMessage` makes when the cached tail
    /// lags behind `channel.lastMessage` — deterministically reproducing the
    /// mid-session `isInitial` redelivery that rapid-traffic sends trigger.
    private static func restartConversationMessageObserver() {
        guard let vc = findChannelViewController(),
              let vm = vc.channelViewModel
        else { return }
        let offset = vm.messageObserver.calculateMessageFetchOffset()
        vm.messageObserver.restartObserver(
            fetchPredicate: vm.messageObserver.defaultFetchPredicate,
            offset: offset
        )
    }

    /// The `ChannelViewController` currently in the window hierarchy, if any.
    private static func findChannelViewController() -> ChannelViewController? {
        func find(_ vc: UIViewController) -> ChannelViewController? {
            if let channel = vc as? ChannelViewController { return channel }
            if let presented = vc.presentedViewController, let found = find(presented) {
                return found
            }
            if let nav = vc as? UINavigationController {
                for child in nav.viewControllers.reversed() {
                    if let found = find(child) { return found }
                }
            }
            for child in vc.children {
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

    /// Runs `action` `delayMs` after the conversation screen starts opening.
    /// "Starts opening" is detected by polling the window hierarchy for the
    /// conversation's collection view (`sceyt_chat_channel_collection_view`),
    /// which enters the hierarchy the moment the push transition begins — so a
    /// delay of 0 lands mid-transition, before `viewDidAppear` and before the
    /// initial scroll position settles, while ~1500+ lands after the screen is
    /// idle.
    private static func scheduleOnConversationOpen(afterMs delayMs: Int,
                                                   _ action: @escaping () -> Void) {
        let timer = Timer(timeInterval: 0.03, repeats: true) { timer in
            guard conversationViewIsInHierarchy() else { return }
            timer.invalidate()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
                action()
            }
        }
        // `.common` so the poll keeps firing while the push transition animates.
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func conversationViewIsInHierarchy() -> Bool {
        func contains(_ view: UIView) -> Bool {
            if view.accessibilityIdentifier == "sceyt_chat_channel_collection_view" { return true }
            return view.subviews.contains(where: contains)
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .contains(where: contains)
    }

    /// Adds two navigation-bar buttons that inject a short / long message onto the
    /// target channel. Present only with `--uitest-inject`, so the other tests
    /// never see them.
    static func installMessageInjector(on viewController: UIViewController) {
        guard isActive, isInjectionEnabled else { return }
        let short = UIBarButtonItem(title: "S", style: .plain,
                                    target: UITestMessageInjector.shared,
                                    action: #selector(UITestMessageInjector.injectShort))
        short.accessibilityIdentifier = "uitest.injectShort"
        let long = UIBarButtonItem(title: "L", style: .plain,
                                   target: UITestMessageInjector.shared,
                                   action: #selector(UITestMessageInjector.injectLong))
        long.accessibilityIdentifier = "uitest.injectLong"
        let markUnread = UIBarButtonItem(title: "U", style: .plain,
                                         target: UITestMessageInjector.shared,
                                         action: #selector(UITestMessageInjector.markTargetUnread))
        markUnread.accessibilityIdentifier = "uitest.markUnread"
        viewController.navigationItem.leftBarButtonItems = [short, long, markUnread]
    }
    #endif
}

#if DEBUG
/// Receives the injector bar-button actions and forwards them to the SDK's
/// test-only message injection. UI-test only.
final class UITestMessageInjector: NSObject {
    static let shared = UITestMessageInjector()

    @objc func injectShort() {
        SceytChatUIKit.shared.receiveUITestMessage(
            channelId: UITestSupport.injectTargetChannelId,
            text: UITestSupport.injectedShortText,
            incoming: true
        )
    }

    @objc func injectLong() {
        SceytChatUIKit.shared.receiveUITestMessage(
            channelId: UITestSupport.injectTargetChannelId,
            text: UITestSupport.injectedLongText,
            incoming: false
        )
    }

    /// Marks the injector's target channel unread locally. The real
    /// `markAs(read:)` needs a server round trip, so this is the only way a UI
    /// test can change a channel's unread state while it is on screen.
    @objc func markTargetUnread() {
        SceytChatUIKit.shared.markUITestChannelUnread(
            channelId: UITestSupport.injectTargetChannelId
        )
    }

    @objc func injectWebSync() {
        UITestSupport.performWebSyncFromButton()
    }

    @objc func pollDoubleVote() {
        UITestSupport.performPollDoubleVoteFromButton()
    }
}
#endif
