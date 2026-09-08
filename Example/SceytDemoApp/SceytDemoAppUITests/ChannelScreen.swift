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
        static let actionTitleLabel = "sceyt_chat_message_input_action_title_label"

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

        // Pinned-messages banner and the context-menu actions that create it.
        static let pinnedMessagesView = "sceyt_chat_channel_pinned_messages_view"
        static let pinnedMessagesTitle = "sceyt_chat_channel_pinned_messages_title"
        static let pinnedMessagesPreview = "sceyt_chat_channel_pinned_messages_preview"
        static let pinnedMessagesButton = "sceyt_chat_channel_pinned_messages_button"
        static let pinnedIcon = "sceyt_chat_channel_message_cell_pinned_icon"

        // The standalone pinned-messages screen the banner's pin button presents.
        static let pinnedListTable = "sceyt_chat_pinned_message_list_table_view"
        static let pinnedListCellRoot = "sceyt_chat_pinned_message_list_cell"
        static func pinnedListCell(_ id: UInt64) -> String { "\(pinnedListCellRoot).\(id)" }
        static let pinnedListNavigateButton = "sceyt_chat_pinned_message_list_navigate_button"
        static let pinnedListCloseButton = "sceyt_chat_pinned_message_list_close_button"
        static let pinnedListEmptyView = "sceyt_chat_pinned_message_list_empty_view"
        static let contextMenuItemRoot = "sceyt_chat_context_menu_item"
        static func contextMenuItem(_ key: String) -> String { "\(contextMenuItemRoot).\(key)" }

        // In-conversation message search controls.
        static let searchNextButton = "sceyt_chat_channel_search_next_button"
        static let searchPreviousButton = "sceyt_chat_channel_search_previous_button"
        static let searchResultLabel = "sceyt_chat_channel_search_result_label"

        // System message cell ("X pinned: ...", "X joined via invite link").
        static let systemCellRoot = "sceyt_chat_channel_system_message_cell"
        static let systemCellTitle = "sceyt_chat_channel_system_message_cell_title"

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

        // Floating attachment-download driver (`--uitest-reply-attachment`): lands
        // the seeded image's bytes and flips its rows to `.done`. Stamps `ok` /
        // `failed` into its own value on commit.
        static let completeAttachmentDownload = "uitest.completeAttachmentDownload"

        // A single attachment view inside a message bubble.
        static let attachmentImage = "sceyt_chat_channel_message_cell_attachment_image"
        /// Thumbnail states published by `attachmentImage` and `replyView` (mirror of
        /// `AccessibilityIdentifiers.Channel.Cell.thumbnail*`).
        static let thumbnailSharp = "thumbnail_sharp"
        static let thumbnailBlurred = "thumbnail_blurred"
        static let thumbnailNone = "thumbnail_none"
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
        /// The outgoing message left in the `.pending` delivery state by
        /// `--uitest-conversation-pending`.
        static let pendingText = "Still sending this one"

        /// Body of the message the floating injector delivers (mirror of
        /// `UITestSupport.injectedShortText`).
        static let injectedText = "Quick hello"

        static func messageId(_ index: UInt64) -> UInt64 { channelId * 10_000 + index }
        static let outgoingId = messageId(18)
        static let lastId = messageId(19)
        static let pendingId = messageId(20)
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

        /// The reply-to-image fixture seeded by `--uitest-reply-attachment`: an
        /// incoming image with no local file (index 21) and an incoming reply
        /// quoting it (index 22). Mirror of `UITestSupport.image*`.
        static let imageMessageId = messageId(21)
        static let imageReplyMessageId = messageId(22)
        static let imageReplyText = "Nice shot!"

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

    /// Floating button that lands the seeded image attachment's download
    /// (present only with `--uitest-reply-attachment`).
    var completeAttachmentDownloadButton: XCUIElement {
        app.buttons[AID.completeAttachmentDownload]
    }

    // MARK: - Attachment thumbnails

    /// The attachment view inside the given message cell. Its `value` says which
    /// thumbnail is on screen: `thumbnailBlurred` while it is still the low-res
    /// `thumbHash` placeholder, `thumbnailSharp` once the downloaded file is
    /// painted.
    func attachmentImage(in cell: XCUIElement) -> XCUIElement {
        cell.otherElements[AID.attachmentImage]
    }

    /// The thumbnail state a message bubble's attachment currently renders, or nil
    /// when the view is not on screen.
    func attachmentThumbnailState(in cell: XCUIElement) -> String? {
        let element = attachmentImage(in: cell)
        guard element.exists else { return nil }
        return element.value as? String
    }

    /// The thumbnail state a cell's reply preview currently renders, or nil when
    /// there is no reply preview on screen.
    func replyThumbnailState(in cell: XCUIElement) -> String? {
        let element = replyView(in: cell)
        guard element.exists else { return nil }
        return element.value as? String
    }

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

    // MARK: - Pinned messages

    /// The banner under the navigation bar. Present in the hierarchy only while the
    /// channel has at least one live pin.
    var pinnedMessagesView: XCUIElement { app.otherElements[AID.pinnedMessagesView] }
    var pinnedMessagesTitle: XCUIElement { app.staticTexts[AID.pinnedMessagesTitle] }
    /// The one-line preview of the pin currently on screen.
    var pinnedMessagesPreview: XCUIElement { app.staticTexts[AID.pinnedMessagesPreview] }
    /// The banner's trailing pin button, which opens the pinned list.
    var pinnedMessagesButton: XCUIElement { app.buttons[AID.pinnedMessagesButton] }

    /// The small pin beside a message's timestamp. Only exists while pinned.
    func pinnedIcon(in cell: XCUIElement) -> XCUIElement { cell.images[AID.pinnedIcon] }

    /// A row in the message context menu, addressed by its unlocalized key
    /// (`pin`, `unpin`, `pinAll`, `pinMe`).
    func contextMenuItem(_ key: String) -> XCUIElement {
        app.cells[AID.contextMenuItem(key)]
    }

    /// Long-presses a message to raise its context menu, then waits for a known row so
    /// the menu is definitely interactive before the caller taps.
    @discardableResult
    func openContextMenu(on cell: XCUIElement, expecting key: String,
                         timeout: TimeInterval = 5) -> Bool {
        cell.press(forDuration: 1.0)
        return contextMenuItem(key).waitForExistence(timeout: timeout)
    }

    /// Pins a message through the real UI: long-press -> Pin -> Pin For All/Me.
    func pinMessage(cell: XCUIElement, forAll: Bool = true, timeout: TimeInterval = 5) {
        XCTAssertTrue(openContextMenu(on: cell, expecting: "pin", timeout: timeout),
                      "the Pin action never appeared in the context menu")
        contextMenuItem("pin").tap()
        let sub = forAll ? "pinAll" : "pinMe"
        XCTAssertTrue(contextMenuItem(sub).waitForExistence(timeout: timeout),
                      "the Pin For All/Me sub-step never appeared")
        contextMenuItem(sub).tap()
    }

    /// Unpins a message through the real UI.
    func unpinMessage(cell: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(openContextMenu(on: cell, expecting: "unpin", timeout: timeout),
                      "the Unpin action never appeared in the context menu")
        contextMenuItem("unpin").tap()
    }

    /// Drags the banner to move to the next / previous pinned message.
    ///
    /// A coordinate drag rather than `swipeUp()`: XCUITest confines a swipe to the
    /// element's frame, and the banner is only ~52pt tall, so the gesture is too short to
    /// read as directional. The drag starts on the banner and travels well past it.
    func swipeToNextPinnedMessage() { dragPinnedBanner(dy: -160) }
    func swipeToPreviousPinnedMessage() { dragPinnedBanner(dy: 160) }

    private func dragPinnedBanner(dy: CGFloat) {
        let start = pinnedMessagesView.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: dy))
        start.press(forDuration: 0.02, thenDragTo: end)
    }

    /// Taps the banner body, which jumps the list to the pin on screen and moves the banner
    /// onto the next one. Off-centre on purpose, so the tap cannot land on the pin button.
    func tapPinnedBanner() {
        pinnedMessagesView.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).tap()
    }

    /// `"<index>/<count>"` — lets a test tell "showing pin 1 of 3" from "only one pin landed".
    var pinnedMessagesValue: String { (pinnedMessagesView.value as? String) ?? "" }

    // MARK: - Pinned-messages list (the screen the banner's pin button presents)

    var pinnedListTable: XCUIElement { app.tables[AID.pinnedListTable] }
    var pinnedListEmptyView: XCUIElement { app.otherElements[AID.pinnedListEmptyView] }
    /// The "X" that dismisses the presented list — it has no back button.
    var pinnedListCloseButton: XCUIElement { app.buttons[AID.pinnedListCloseButton] }
    /// A row in the pinned-messages list, addressable by its seeded message id.
    func pinnedListCell(_ id: UInt64) -> XCUIElement { app.cells[AID.pinnedListCell(id)] }

    /// A row's arrow button: the one control on the screen that leaves it, jumping the
    /// conversation to that message. Tapping the bubble does what it does in the
    /// conversation instead.
    func pinnedListNavigateButton(in cell: XCUIElement) -> XCUIElement {
        cell.buttons[AID.pinnedListNavigateButton]
    }

    /// A row's body text. The rows are the conversation's own message cells, so it is the
    /// message body label, not a preview of its own.
    func pinnedListBody(in cell: XCUIElement) -> XCUIElement {
        cell.staticTexts[AID.body]
    }

    /// Every row currently realized in the list, top to bottom, by its identifier — which
    /// is what tells "all three pins are listed, in timeline order" from "some rows
    /// appeared". Filtered by prefix because a row *hosts* a message cell, so the message
    /// cell shows up as a cell of its own.
    var pinnedListRowIdentifiers: [String] {
        pinnedListTable.cells.allElementsBoundByIndex
            .map(\.identifier)
            .filter { $0.hasPrefix(AID.pinnedListCellRoot) }
    }

    /// Every message body currently realized in the list, top to bottom. A pin with no
    /// text of its own — a caption-less video, a poll — contributes nothing.
    var pinnedListBodies: [String] {
        pinnedListTable.staticTexts.matching(identifier: AID.body)
            .allElementsBoundByIndex
            .map(\.label)
    }

    /// Opens the pinned-messages list through the real UI and waits for its table.
    @discardableResult
    func openPinnedMessageList(timeout: TimeInterval = 5) -> Bool {
        pinnedMessagesButton.tap()
        return pinnedListTable.waitForExistence(timeout: timeout)
    }

    /// Dismisses the presented pinned-messages list through its "X".
    func closePinnedMessageList() {
        pinnedListCloseButton.tap()
    }

    /// A specific message cell, addressable by its seeded id.
    func cell(_ id: UInt64) -> XCUIElement { app.cells[AID.cell(id)] }

    /// A system-message row carrying exactly `text`.
    ///
    /// Matched on the text rather than on a message id: a system message the app has just
    /// posted has no server id yet, so its row identifier is still `...cell.0`.
    func systemMessage(_ text: String) -> XCUIElement {
        systemMessages
            .staticTexts
            .matching(NSPredicate(format: "identifier == %@ AND label == %@",
                                  AID.systemCellTitle, text))
            .firstMatch
    }

    /// Every system-message row currently rendered.
    var systemMessages: XCUIElementQuery {
        app.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", AID.systemCellRoot + "."))
    }

    /// The body text of a specific message cell.
    func body(in cell: XCUIElement) -> XCUIElement { cell.staticTexts[AID.body] }

    /// The timestamp inside a specific message cell — the info row's anchor, and what a
    /// pin or an "edited" mark has to make room beside rather than land on top of.
    func date(in cell: XCUIElement) -> XCUIElement { cell.staticTexts[AID.date] }

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

    // MARK: - Composer action bar (reply / edit preview)

    /// The cancel button of the reply/edit preview above the composer. The preview is hidden
    /// until an action is active, so its mere existence means "the bar is showing".
    var actionCancelButton: XCUIElement { app.buttons[AID.actionCancelButton] }

    /// The preview's title — "Reply: <name>" or "Edit: ", i.e. what tells the modes apart.
    var actionTitle: XCUIElement { app.staticTexts[AID.actionTitleLabel] }

    var hasActionBar: Bool { actionCancelButton.exists }

    @discardableResult
    func waitForActionBar(timeout: TimeInterval = 5) -> Bool {
        actionCancelButton.waitForExistence(timeout: timeout)
    }

    /// Long-presses a message and taps a context-menu item by its visible title.
    ///
    /// The menu rows are `MenuController.MenuCell`s carrying a plain `UILabel`, so they surface as
    /// static texts rather than buttons; buttons are tried too in case the row is wrapped.
    func performContextMenuAction(_ title: String, on messageId: UInt64) {
        let target = cell(messageId)
        _ = target.waitForExistence(timeout: 10)
        target.press(forDuration: 0.7)

        tapContextMenuItem(title)
    }

    /// Long-presses the first realized cell whose body contains `text`, then taps a menu item.
    /// Needed for a message the test just sent, whose id the test does not know.
    func performContextMenuAction(_ title: String, onCellContaining text: String) {
        guard let target = visibleMessageCells.first(where: {
            $0.staticTexts[AID.body].exists && $0.staticTexts[AID.body].label.contains(text)
        }) else {
            return XCTFail("no message cell containing \"\(text)\"")
        }
        target.press(forDuration: 0.7)
        tapContextMenuItem(title)
    }

    /// The menu rows carry a plain `UILabel`, so they surface as static texts rather than
    /// buttons; the other queries cover a wrapped row.
    private func tapContextMenuItem(_ title: String) {
        for query in [app.staticTexts[title], app.buttons[title], app.cells[title]] {
            if query.waitForExistence(timeout: 3) {
                query.tap()
                return
            }
        }
        XCTFail("context-menu item \"\(title)\" never appeared")
    }

    /// Types `text` into the composer without sending it.
    func type(_ text: String) {
        inputField.tap()
        inputField.typeText(text)
    }

    /// Replaces whatever the composer holds with `text`.
    func clearAndType(_ text: String) {
        inputField.tap()
        guard let existing = inputField.value as? String, !existing.isEmpty else {
            inputField.typeText(text)
            return
        }
        inputField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        inputField.typeText(text)
    }

    var composerText: String { (inputField.value as? String) ?? "" }
}
