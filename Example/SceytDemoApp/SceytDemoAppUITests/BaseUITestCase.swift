//
//  BaseUITestCase.swift
//  SceytDemoAppUITests
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import XCTest

/// Shared launch plumbing for the channel-list UI tests.
///
/// Every test launches the app in the deterministic `--uitest` mode (see
/// `UITestSupport` in the app target): login and the live connection are skipped
/// and a fixed set of channels is seeded into the local database.
class BaseUITestCase: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches the app in UI-test mode.
    /// - Parameters:
    ///   - empty: seed no channels (exercises the empty list).
    ///   - conversation: seed a single channel with a rich message history for the
    ///     open-channel (`ChannelViewController`) tests.
    ///   - conversationUnread: like `conversation`, but also marks unread messages
    ///     so the "New messages" separator renders.
    ///   - conversationUnreadCount: seed the conversation with the standard history
    ///     up to the last-read message plus exactly this many trailing *incoming*
    ///     unread messages (implies conversation mode; see
    ///     `ChannelScreen.Conversation.unreadTailId`).
    ///   - conversationUnreadLong: make the seeded unread tail multi-line long
    ///     bodies instead of one-liners (probes estimated-height positioning).
    ///   - conversationUnreadRecent: date the seeded unread tail *today* while the
    ///     history keeps its old day, forcing a date-separator boundary before the
    ///     unread messages (probes separator-height handling in the open position).
    ///   - injectOnOpenDelayMs: auto-inject one incoming message this many ms after
    ///     the conversation screen starts opening (0 = mid push-transition, before
    ///     the initial scroll position settles).
    ///   - growNewestOnOpenDelayMs: rewrite the newest seeded message's body to a
    ///     long multi-line text this many ms after the conversation screen starts
    ///     opening — the bottom cell grows in place, like a link preview or
    ///     attachment thumbnail arriving asynchronously. Requires
    ///     `conversationUnreadCount`.
    ///   - injectBurstOnOpenDelayMs: this many ms after the conversation screen
    ///     starts opening, insert `injectBurstCount` incoming messages in ONE
    ///     database transaction — a single observer event whose diff carries a
    ///     multi-insert batch, like a server sync delivering several messages at
    ///     once (see `ChannelScreen.Conversation.burstText`).
    ///   - injectBurstCount: how many messages the burst inserts (default 6).
    ///   - injectOnKeyboardDelayMs: inject one incoming message this many ms after
    ///     the keyboard starts presenting — lands the insert inside the keyboard's
    ///     inset animation window.
    ///   - restartObserverOnOpenDelayMs: this many ms after the conversation
    ///     screen starts opening, restart its message observer the way a send
    ///     does when the cached tail lags behind `channel.lastMessage` — the
    ///     mid-session `isInitial` redelivery of rapid-traffic sends, made
    ///     deterministic.
    ///   - messageStormPairs: `messageStormStartMs` after the conversation opens,
    ///     fire this many timer ticks every `messageStormIntervalMs`, each
    ///     inserting one outgoing and one incoming message back-to-back (see
    ///     `ChannelScreen.Conversation.stormSentText/stormReceivedText`). A small
    ///     start delay (200) makes the storm the first traffic the open screen
    ///     sees — an already-busy channel.
    ///   - webSyncButtonCount: install a floating button (`uitest.injectWebSync`)
    ///     that, on tap, inserts this many OUTGOING "sent from the Web client"
    ///     messages in ONE database transaction, dated BETWEEN the last-read
    ///     message and the unread incoming tail — a server sync delivering the
    ///     same account's other-device messages into the middle of the loaded
    ///     history (see `ChannelScreen.Conversation.webSyncText`).
    ///   - webSyncButtonRestart: the web-sync button tap also restarts the
    ///     conversation's message observer right after the insert — the window
    ///     recalculation the real sync pipeline performs, which re-delivers an
    ///     `isInitial` change event.
    ///   - webSyncOnOpenDelayMs: fire the same web-sync insert automatically
    ///     this many ms after the conversation screen starts opening (150 =
    ///     mid push-transition, ~2000 = after the open has settled).
    ///   - webSyncOnOpenCount: how many messages the scheduled web-sync insert
    ///     delivers (default 8 — tall enough to overflow any phone screen).
    ///   - webSyncOnOpenRestart: the scheduled web-sync insert also restarts the
    ///     message observer, like `webSyncButtonRestart`.
    ///   - webSyncSeededCount: bake this many Web-sent outgoing messages into
    ///     the seeded conversation itself, between the last-read message and
    ///     the unread tail — a cold start whose sync completed BEFORE the
    ///     channel was opened (requires `conversationUnreadCount`).
    ///   - poll: seed a short conversation whose newest message is a poll, so the
    ///     in-bubble poll view is on screen as soon as the channel opens. Poll-vote
    ///     requests complete locally (this mode never connects), so a *changed*
    ///     vote can be driven.
    ///   - pollAllowsMultipleVotes: make the seeded poll multiple-choice; the
    ///     default is single-choice, where at most one option may render as voted.
    ///   - pollDoubleVoteGapMs: install a floating button
    ///     (`uitest.pollDoubleVote`) that votes for the first poll option and then,
    ///     this many ms later, for the second one — the "change my vote right away"
    ///     gesture at a gap XCUITest cannot deliver on its own. Requires `poll`.
    ///   - dynamicTypeCategory: optional `UICTContentSizeCategory…` name to force
    ///     a Dynamic Type size, e.g. `"UICTContentSizeCategoryAccessibilityXXXL"`.
    @discardableResult
    func launchApp(empty: Bool = false,
                   injectionEnabled: Bool = false,
                   conversation: Bool = false,
                   conversationUnread: Bool = false,
                   conversationUnreadCount: Int? = nil,
                   conversationUnreadLong: Bool = false,
                   conversationUnreadRecent: Bool = false,
                   injectOnOpenDelayMs: Int? = nil,
                   growNewestOnOpenDelayMs: Int? = nil,
                   injectBurstOnOpenDelayMs: Int? = nil,
                   injectBurstCount: Int = 6,
                   injectOnKeyboardDelayMs: Int? = nil,
                   restartObserverOnOpenDelayMs: Int? = nil,
                   messageStormPairs: Int? = nil,
                   messageStormIntervalMs: Int = 300,
                   messageStormStartMs: Int = 1500,
                   webSyncButtonCount: Int? = nil,
                   webSyncButtonRestart: Bool = false,
                   webSyncOnOpenDelayMs: Int? = nil,
                   webSyncOnOpenCount: Int = 8,
                   webSyncOnOpenRestart: Bool = false,
                   webSyncSeededCount: Int? = nil,
                   poll: Bool = false,
                   pollAllowsMultipleVotes: Bool = false,
                   pollDoubleVoteGapMs: Int? = nil,
                   dynamicTypeCategory: String? = nil,
                   imperativeDataSource: Bool = false,
                   fullSwipeActions: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest"]
        if empty {
            app.launchArguments += ["--uitest-empty"]
        }
        if injectionEnabled {
            app.launchArguments += ["--uitest-inject"]
        }
        if conversation {
            app.launchArguments += ["--uitest-conversation"]
        }
        if conversationUnread {
            app.launchArguments += ["--uitest-conversation-unread"]
        }
        if let count = conversationUnreadCount {
            app.launchArguments += ["--uitest-conversation-unread-count=\(count)"]
        }
        if conversationUnreadLong {
            app.launchArguments += ["--uitest-conversation-unread-long"]
        }
        if conversationUnreadRecent {
            app.launchArguments += ["--uitest-conversation-unread-recent"]
        }
        if let delayMs = injectOnOpenDelayMs {
            app.launchArguments += ["--uitest-inject-on-open=\(delayMs)"]
        }
        if let delayMs = growNewestOnOpenDelayMs {
            app.launchArguments += ["--uitest-grow-newest-on-open=\(delayMs)"]
        }
        if let delayMs = injectBurstOnOpenDelayMs {
            app.launchArguments += ["--uitest-inject-burst-on-open=\(delayMs)x\(injectBurstCount)"]
        }
        if let delayMs = injectOnKeyboardDelayMs {
            app.launchArguments += ["--uitest-inject-on-keyboard=\(delayMs)"]
        }
        if let delayMs = restartObserverOnOpenDelayMs {
            app.launchArguments += ["--uitest-restart-observer-on-open=\(delayMs)"]
        }
        if let pairs = messageStormPairs {
            app.launchArguments +=
                ["--uitest-message-storm=\(pairs)x\(messageStormIntervalMs)x\(messageStormStartMs)"]
        }
        if let count = webSyncButtonCount {
            app.launchArguments +=
                ["--uitest-web-sync-button=\(count)" + (webSyncButtonRestart ? "xrestart" : "")]
        }
        if let delayMs = webSyncOnOpenDelayMs {
            app.launchArguments +=
                ["--uitest-web-sync-on-open=\(delayMs)x\(webSyncOnOpenCount)"
                    + (webSyncOnOpenRestart ? "xrestart" : "")]
        }
        if let count = webSyncSeededCount {
            app.launchArguments += ["--uitest-web-sync-seeded=\(count)"]
        }
        if poll {
            app.launchArguments += pollAllowsMultipleVotes
                ? ["--uitest-poll=multiple"]
                : ["--uitest-poll"]
        }
        if let gapMs = pollDoubleVoteGapMs {
            app.launchArguments += ["--uitest-poll-double-vote=\(gapMs)"]
        }
        if let category = dynamicTypeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", category]
        }
        if imperativeDataSource {
            app.launchArguments += ["--uitest-imperative"]
        }
        if fullSwipeActions {
            app.launchArguments += ["--uitest-full-swipe"]
        }
        app.launch()
        return app
    }
}
