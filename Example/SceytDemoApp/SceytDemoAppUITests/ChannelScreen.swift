//
//  ChannelScreen.swift
//  SceytDemoAppUITests
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import XCTest

/// Page object for the open-channel (conversation) screen — its message list, the
/// navigation header, the scroll-to-bottom button and the message composer.
///
/// The accessibility-identifier strings are mirrored (not imported) from
/// `SceytChatUIKit.AccessibilityIdentifiers.Channel` / `.MessageInput` so the
/// UI-test bundle stays free of the SDK link dependency. Keep in sync with
/// `SceytChatUIKitAccessibilityIdentifiers.swift`.
struct ChannelScreen {

    let app: XCUIApplication

    enum AID {
        // Message composer.
        static let inputField = "sceyt_chat_message_input_field"
        static let sendButton = "sceyt_chat_message_input_send_button"
        static let attachmentButton = "sceyt_chat_message_input_attachment_button"
        static let cameraButton = "sceyt_chat_message_input_camera_button"
        static let voiceButton = "sceyt_chat_message_input_voice_button"
        static let viewOnceButton = "sceyt_chat_message_input_view_once_button"
        static let actionCancelButton = "sceyt_chat_message_input_action_cancel_button"

        // Conversation screen.
        static let collectionView = "sceyt_chat_channel_collection_view"
        static let title = "sceyt_chat_channel_title"
        static let subtitle = "sceyt_chat_channel_subtitle"
        static let avatar = "sceyt_chat_channel_avatar"
        static let scrollDownButton = "sceyt_chat_channel_scroll_down_button"
        static let unreadMentionButton = "sceyt_chat_channel_unread_mention_button"
        static let joinButton = "sceyt_chat_channel_join_button"
        static let emptyView = "sceyt_chat_channel_empty_view"
        static let searchBar = "sceyt_chat_channel_search_bar"

        // In-conversation message search controls.
        static let searchNextButton = "sceyt_chat_channel_search_next_button"
        static let searchPreviousButton = "sceyt_chat_channel_search_previous_button"
        static let searchResultLabel = "sceyt_chat_channel_search_result_label"

        // Message cell.
        static let cellRoot = "sceyt_chat_channel_message_cell"
        static func cell(_ id: UInt64) -> String { "\(cellRoot).\(id)" }
        static let body = "sceyt_chat_channel_message_cell_body"
        static let date = "sceyt_chat_channel_message_cell_date"
        static let unreadSeparator = "sceyt_chat_channel_message_cell_unread_separator"
        static let replyView = "sceyt_chat_channel_message_cell_reply_view"

        // In-bubble poll view and its option rows (`--uitest-poll`).
        static let poll = "sceyt_chat_channel_message_cell_poll"
        static let pollOptionRoot = "sceyt_chat_channel_message_cell_poll_option"
        static func pollOption(_ index: Int) -> String { "\(pollOptionRoot).\(index)" }
        /// `accessibilityValue` an option row carries while the current user's vote
        /// sits on it (mirror of `MessageCell.PollOptionView.votedAccessibilityValue`).
        static let pollOptionVoted = "voted"
        static let pollOptionNotVoted = "not_voted"

        // Floating incoming-message injector (conversation mode + `--uitest-inject`).
        static let injectIncoming = "uitest.injectIncoming"

        // Floating web-sync injector (conversation mode +
        // `--uitest-web-sync-button`): delivers the "sent from the Web client"
        // batch that sorts into the middle of the history.
        static let injectWebSync = "uitest.injectWebSync"

        // Floating rapid-vote-change driver (`--uitest-poll-double-vote=<gapMs>`):
        // votes for the first poll option, then for the second one.
        static let pollDoubleVote = "uitest.pollDoubleVote"
    }

    /// Mirror of the conversation seeded by `UITestSupport` (`--uitest-conversation`).
    /// The channel id is fixed so a cell can be addressed as
    /// `sceyt_chat_channel_message_cell.<id>`.
    enum Conversation {
        static let channelId: UInt64 = 100
        static let subject = "UITest Chat"

        static let firstText = "Start of the conversation"
        static let lastReadText = "This is the last read message"
        static let outgoingText = "My outgoing reply"
        static let lastText = "This is the newest message"

        /// Body of the message the floating injector delivers (mirror of
        /// `UITestSupport.injectedShortText`).
        static let injectedText = "Quick hello"

        static func messageId(_ index: UInt64) -> UInt64 { channelId * 10_000 + index }
        static let outgoingId = messageId(18)
        static let lastId = messageId(19)
        static let afterReadId = messageId(17)
        static let lastReadId = messageId(16)
        static let firstId = messageId(1)

        /// The outgoing message (index 18) is an inline reply quoting the first
        /// message (index 1).
        static let replyMessageId = messageId(18)
        static let repliedToId = firstId
        static let repliedToText = firstText

        /// The parametrized unread tail (`--uitest-conversation-unread-count=N`):
        /// id/body of the `n`-th (1-based) of the N incoming unread messages
        /// seeded after the last-read message (index 16). Mirror of
        /// `UITestSupport.conversationUnreadTailText`.
        static func unreadTailId(_ n: Int) -> UInt64 { messageId(UInt64(16 + n)) }
        static func unreadTailText(_ n: Int) -> String { "Unread incoming \(n)" }

        /// Bodies of the messages the `--uitest-message-storm` knob inserts —
        /// the `n`-th (1-based) outgoing / incoming storm message. Mirror of
        /// `UITestSupport.conversationStormSentText/conversationStormReceivedText`.
        static func stormSentText(_ n: Int) -> String { "Storm sent \(n)" }
        static func stormReceivedText(_ n: Int) -> String { "Storm received \(n)" }

        /// Body of the `n`-th message a `--uitest-inject-burst-on-open` batch
        /// inserts. Mirror of `UITestSupport.conversationBurstText`.
        static func burstText(_ n: Int) -> String {
            "Burst incoming \(n) — this body is deliberately long so the bubble wraps "
                + "across several lines and the whole batch is tall enough to push "
                + "the New-messages separator a full screen away from the bottom."
        }

        /// Body of the `n`-th message a web-sync insert delivers — an OUTGOING
        /// message the same account sent from the Web client, arriving late via
        /// server sync and sorting in ABOVE the received messages. Mirror of
        /// `UITestSupport.conversationWebSyncText`.
        static func webSyncText(_ n: Int) -> String {
            "Sent from Web \(n) — this message was written on the Web client of the "
                + "same account before the incoming messages arrived, and it reaches "
                + "this device only later, through a server sync, so it must slot in "
                + "ABOVE the received messages without moving the viewport."
        }

        /// The poll fixture seeded by `--uitest-poll`: a poll as the newest message
        /// of a short history. Mirror of `UITestSupport.poll*`.
        static let pollMessageId = messageId(20)
        static let pollQuestion = "Which option do you pick?"
        static let pollOptionTexts = ["First option", "Second option", "Third option"]

        /// The multi-line body `--uitest-grow-newest-on-open` rewrites the newest
        /// message to. Mirror of `UITestSupport.conversationGrownBodyText`.
        static let grownBodyText =
            "This body replaced the original one after the screen opened and is "
                + "deliberately long enough to wrap across several lines, so the "
                + "bottom-most cell grows in place well after the initial scroll "
                + "position has settled."
    }

    // MARK: - Composer

    var inputField: XCUIElement { app.textViews[AID.inputField] }

    /// The send button is hidden until the composer holds non-whitespace text, so
    /// it only resolves after text has been typed.
    var sendButton: XCUIElement { app.buttons[AID.sendButton] }

    // MARK: - Message list

    var collectionView: XCUIElement { app.collectionViews[AID.collectionView] }

    var scrollDownButton: XCUIElement { app.buttons[AID.scrollDownButton] }

    /// Floating button that injects an incoming message into the open
    /// conversation (present only with `--uitest-inject` in conversation mode).
    var injectIncomingButton: XCUIElement { app.buttons[AID.injectIncoming] }

    /// Floating button that delivers the web-sync batch into the open
    /// conversation (present only with `--uitest-web-sync-button` in
    /// conversation mode).
    var injectWebSyncButton: XCUIElement { app.buttons[AID.injectWebSync] }

    /// Floating button that votes for the first poll option and then, after the
    /// configured gap, for the second one (present only with
    /// `--uitest-poll-double-vote=<gapMs>`).
    var pollDoubleVoteButton: XCUIElement { app.buttons[AID.pollDoubleVote] }

    /// The "New messages" separator, shown on the last-read message.
    var unreadSeparator: XCUIElement { app.staticTexts[AID.unreadSeparator] }

    // MARK: - Poll

    /// The in-bubble poll view of the poll message.
    var pollView: XCUIElement { app.otherElements[AID.poll] }

    /// A poll option row, addressed by its zero-based row index.
    func pollOption(_ index: Int) -> XCUIElement { app.otherElements[AID.pollOption(index)] }

    /// Whether the option row at `index` renders as voted by the current user.
    /// Reads the value the row publishes right where it sets its checkbox image, so
    /// this is the state a user sees, stale updates included.
    func pollOptionIsVoted(_ index: Int) -> Bool {
        (pollOption(index).value as? String) == AID.pollOptionVoted
    }

    /// Row indexes of every realized poll option that currently renders as voted.
    func votedPollOptionIndexes(upTo optionCount: Int) -> [Int] {
        (0..<optionCount).filter { pollOptionIsVoted($0) }
    }

    /// A readable dump of every option row's vote state, for failure messages.
    func pollVoteStateDescription(optionCount: Int) -> String {
        (0..<optionCount)
            .map { "option \($0)=\((pollOption($0).value as? String) ?? "<no value>")" }
            .joined(separator: ", ")
    }

    /// A specific message cell, addressable by its seeded id.
    func cell(_ id: UInt64) -> XCUIElement { app.cells[AID.cell(id)] }

    /// The body text of a specific message cell.
    func body(in cell: XCUIElement) -> XCUIElement { cell.staticTexts[AID.body] }

    /// The quoted reply preview inside a specific message cell.
    func replyView(in cell: XCUIElement) -> XCUIElement { cell.buttons[AID.replyView] }

    /// All currently-realized message cells, in display order.
    var visibleMessageCells: [XCUIElement] {
        app.cells.allElementsBoundByIndex.filter { $0.identifier.hasPrefix(AID.cellRoot) }
    }

    // MARK: - Header

    var title: XCUIElement { app.staticTexts[AID.title] }

    // MARK: - Navigation

    /// The standard navigation-bar back button (the leftmost bar item — the
    /// channel screen shows only the system back button on the left).
    var backButton: XCUIElement { app.navigationBars.buttons.element(boundBy: 0) }

    // MARK: - Actions

    /// Waits for the composer to be present (the channel has finished opening).
    @discardableResult
    func waitUntilReady(timeout: TimeInterval = 10) -> Bool {
        inputField.waitForExistence(timeout: timeout)
    }

    /// Types `text` into the composer and taps send.
    func send(_ text: String) {
        inputField.tap()
        inputField.typeText(text)
        _ = sendButton.waitForExistence(timeout: 5)
        sendButton.tap()
    }

    /// Pops back to the channel list.
    func goBack() {
        backButton.tap()
    }
}
