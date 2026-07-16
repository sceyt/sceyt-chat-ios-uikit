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
        if isConversation || isConversationUnread || conversationUnreadCountOverride != nil {
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
        let short = UIBarButtonItem(title: "InjectShort", style: .plain,
                                    target: UITestMessageInjector.shared,
                                    action: #selector(UITestMessageInjector.injectShort))
        short.accessibilityIdentifier = "uitest.injectShort"
        let long = UIBarButtonItem(title: "InjectLong", style: .plain,
                                   target: UITestMessageInjector.shared,
                                   action: #selector(UITestMessageInjector.injectLong))
        long.accessibilityIdentifier = "uitest.injectLong"
        viewController.navigationItem.leftBarButtonItems = [short, long]
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
}
#endif
