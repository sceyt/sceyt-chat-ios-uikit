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

    /// Call as early as possible at launch, right after `configureSceytChatUIKit()`.
    static func bootstrapIfNeeded() {
        guard isActive else { return }
        #if DEBUG
        SceytChatUIKit.shared.startUITestSession()
        SceytChatUIKit.shared.seedChannelsForUITests(isEmpty ? [] : fixtures)
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
