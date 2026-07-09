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

    /// Call as early as possible at launch, right after `configureSceytChatUIKit()`.
    static func bootstrapIfNeeded() {
        guard isActive else { return }
        #if DEBUG
        SceytChatUIKit.shared.startUITestSession()
        if isConversation || isConversationUnread {
            seedConversation(withUnread: isConversationUnread)
        } else {
            SceytChatUIKit.shared.seedChannelsForUITests(isEmpty ? [] : fixtures)
        }
        #endif
    }

    #if DEBUG
    /// One channel per cell state the UI tests assert on. Ids are fixed so a test
    /// can address a row directly via `channelCell.<id>`.
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

    private static func seedConversation(withUnread: Bool) {
        SceytChatUIKit.shared.seedChannelsForUITests([
            .init(id: conversationChannelId, subject: conversationSubject)
        ])
        SceytChatUIKit.shared.seedMessagesForUITests(
            channelId: conversationChannelId,
            messages: conversationMessages,
            // 3 unread messages (indices 17–19) sitting after the last read one.
            unreadCount: withUnread ? 3 : 0,
            lastDisplayedMessageId: withUnread ? conversationMessageId(16) : 0
        )
    }

    // MARK: - Message injection (test-only, gated behind --uitest-inject)

    /// The channel the injector targets — id 1 "Design Team", the oldest seeded
    /// channel, which starts at the bottom of the list.
    static let injectTargetChannelId: UInt64 = 1
    static let injectedShortText = "Quick hello"
    static let injectedLongText = "This is a deliberately long preview message that should wrap across two lines in the channel list to verify the two-line layout."

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
