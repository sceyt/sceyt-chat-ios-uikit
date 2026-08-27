//
//  ChannelDraftUITests.swift
//  SceytDemoAppUITests
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//
//  Black-box tests for restoring the message composer after leaving a channel. Before this, only
//  the typed text came back: tapping Reply, typing, leaving and returning left the text in place
//  with no reply bar, and the message then sent as a plain message — silently losing the reply.
//
//  `goBack()` performs a real navigation pop, which is exactly the trigger the draft is saved on.
//

import XCTest

final class ChannelDraftUITests: BaseUITestCase {

    private typealias Convo = ChannelScreen.Conversation

    private var app: XCUIApplication!
    private var list: ChannelListScreen!
    private var screen: ChannelScreen!

    /// Titles of the context-menu rows, mirroring `L10n.Message.Action.Title`.
    private enum MenuTitle {
        static let reply = "Reply"
        static let edit = "Edit"
    }

    private func openConversation() {
        app = launchApp(injectionEnabled: false, conversation: true, conversationUnread: false)
        list = ChannelListScreen(app: app)
        screen = ChannelScreen(app: app)

        XCTAssertTrue(list.waitUntilLoaded(), "The channel list should load")
        openChannelFromList()
    }

    /// Taps into the seeded channel from the list and waits for the composer.
    private func openChannelFromList() {
        let listCell = list.cell(Convo.channelId)
        XCTAssertTrue(listCell.waitForExistence(timeout: 10),
                      "The seeded conversation channel should appear in the list")
        listCell.tap()

        XCTAssertTrue(screen.waitUntilReady(), "The channel composer should appear")
        XCTAssertTrue(screen.collectionView.waitForExistence(timeout: 10),
                      "The message list should appear")
    }

    /// Sends a message and returns its body text.
    ///
    /// The seeded history is dated 2023, well outside `messageEditTimeout`, so `canEdit` refuses
    /// it — the edit tests need a message of their own.
    @discardableResult
    private func sendEditableMessage(_ text: String = "editable message") -> String {
        screen.send(text)
        XCTAssertTrue(
            waitFor(timeout: 10) { [self] in
                screen.visibleMessageCells.contains {
                    $0.staticTexts[ChannelScreen.AID.body].exists
                        && $0.staticTexts[ChannelScreen.AID.body].label.contains(text)
                }
            },
            "The sent message should appear before it can be edited"
        )
        return text
    }

    /// Leaves the channel (saving the draft) and comes back (restoring it).
    private func roundTrip() {
        screen.goBack()
        XCTAssertTrue(list.waitUntilLoaded(), "Should return to the channel list")
        openChannelFromList()
    }

    // MARK: - Reply

    func test_replyDraft_survivesLeavingAndReopeningTheChannel() {
        openConversation()

        screen.performContextMenuAction(MenuTitle.reply, on: Convo.messageId(19))
        XCTAssertTrue(screen.waitForActionBar(), "Tapping Reply should show the reply bar")
        screen.type("my reply text")

        roundTrip()

        XCTAssertTrue(screen.waitForActionBar(),
                      "The reply bar should come back with the draft, not just the text")
        XCTAssertTrue(screen.actionTitle.label.contains("Reply"),
                      "The restored bar should be a reply; was: \(screen.actionTitle.label)")
        XCTAssertTrue(screen.composerText.contains("my reply text"),
                      "The typed text should be restored; was: \(screen.composerText)")
    }

    /// The regression that actually matters: a restored bar is worthless if the send path has
    /// forgotten the target. This proves the view model was rehydrated, not just the UI redrawn.
    func test_sendingAfterRestoringAReplyDraft_stillRepliesToTheMessage() {
        openConversation()

        screen.performContextMenuAction(MenuTitle.reply, on: Convo.messageId(19))
        XCTAssertTrue(screen.waitForActionBar())
        screen.type("restored reply")

        roundTrip()
        XCTAssertTrue(screen.waitForActionBar(), "The reply bar should be restored before sending")

        _ = screen.sendButton.waitForExistence(timeout: 5)
        screen.sendButton.tap()

        // The sent bubble must carry the quoted parent, which only happens when the message was
        // built with a reply action.
        XCTAssertTrue(
            waitFor(timeout: 10) { [self] in
                screen.visibleMessageCells.contains { cell in
                    screen.replyView(in: cell).exists
                        && cell.staticTexts[ChannelScreen.AID.body].label.contains("restored reply")
                }
            },
            "The sent message should render as a reply, not a plain message"
        )
    }

    func test_replyDraft_withoutTypedText_stillRestoresTheReplyBar() {
        openConversation()

        screen.performContextMenuAction(MenuTitle.reply, on: Convo.messageId(19))
        XCTAssertTrue(screen.waitForActionBar())

        roundTrip()

        XCTAssertTrue(screen.waitForActionBar(),
                      "Tapping Reply and walking away is still intent worth restoring")
    }

    func test_cancellingARestoredReply_clearsItForGood() {
        openConversation()

        screen.performContextMenuAction(MenuTitle.reply, on: Convo.messageId(19))
        XCTAssertTrue(screen.waitForActionBar())
        screen.type("never mind")

        roundTrip()
        XCTAssertTrue(screen.waitForActionBar())

        screen.actionCancelButton.tap()
        XCTAssertTrue(waitFor { [self] in !screen.hasActionBar }, "Cancel should dismiss the reply bar")

        roundTrip()
        XCTAssertFalse(screen.hasActionBar, "A cancelled reply should not come back")
    }

    // MARK: - Edit

    func test_editDraft_survivesRoundTripAndKeepsTheEditedText() {
        openConversation()

        let sent = sendEditableMessage("message to edit")
        screen.performContextMenuAction(MenuTitle.edit, onCellContaining: sent)
        XCTAssertTrue(screen.waitForActionBar(), "Tapping Edit should show the edit bar")
        screen.clearAndType("edited body")

        roundTrip()

        XCTAssertTrue(screen.waitForActionBar(), "The edit bar should come back")
        XCTAssertTrue(screen.actionTitle.label.contains("Edit"),
                      "The restored bar should be an edit; was: \(screen.actionTitle.label)")
        XCTAssertTrue(screen.composerText.contains("edited body"),
                      "The in-progress edit text should be restored; was: \(screen.composerText)")
    }

    /// Entering edit mode parks the real draft in `cachedMessage`; the draft persists both, so
    /// cancelling a *restored* edit must still fall back to what the user had typed.
    func test_cancellingARestoredEdit_fallsBackToThePreEditDraft() {
        openConversation()

        let sent = sendEditableMessage("message to edit")
        screen.type("my own draft")
        screen.performContextMenuAction(MenuTitle.edit, onCellContaining: sent)
        XCTAssertTrue(screen.waitForActionBar())
        screen.clearAndType("temporary edit")

        roundTrip()
        XCTAssertTrue(screen.waitForActionBar(), "The edit bar should be restored")

        screen.actionCancelButton.tap()
        XCTAssertTrue(waitFor { [self] in !screen.hasActionBar }, "Cancel should dismiss the edit bar")
        XCTAssertTrue(
            waitFor { [self] in screen.composerText.contains("my own draft") },
            "Cancelling should restore the pre-edit draft; was: \(screen.composerText)"
        )
    }

    /// While editing, the cell previews the message being edited — that is the pending work. The
    /// draft parked behind the edit is still kept; `test_cancellingARestoredEdit_...` covers that.
    func test_pendingEdit_previewsTheEditedMessageOnTheChannelCell() {
        openConversation()

        let sent = sendEditableMessage("message to edit")
        screen.type("parked draft")
        screen.performContextMenuAction(MenuTitle.edit, onCellContaining: sent)
        XCTAssertTrue(screen.waitForActionBar())
        screen.clearAndType("the full edited message")

        screen.goBack()
        XCTAssertTrue(list.waitUntilLoaded(), "Should return to the channel list")

        let listCell = list.cell(Convo.channelId)
        XCTAssertTrue(listCell.waitForExistence(timeout: 10))
        let preview = list.message(in: listCell)
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.label.contains("Draft"),
                      "The cell should still mark it as a draft; was: \(preview.label)")
        XCTAssertTrue(preview.label.contains("the full edited message"),
                      "The edited message is what should show; was: \(preview.label)")
    }

    // MARK: - Channel-cell preview

    /// Reply, type nothing, leave — the cell should say "Draft: Reply" rather than falling back to
    /// the last message as if nothing were pending.
    func test_replyWithoutText_previewsAsDraftReplyOnTheChannelCell() {
        openConversation()

        screen.performContextMenuAction(MenuTitle.reply, on: Convo.messageId(19))
        XCTAssertTrue(screen.waitForActionBar())

        screen.goBack()
        XCTAssertTrue(list.waitUntilLoaded(), "Should return to the channel list")

        let listCell = list.cell(Convo.channelId)
        XCTAssertTrue(listCell.waitForExistence(timeout: 10))
        let preview = list.message(in: listCell)
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "The cell should show a subtitle")
        XCTAssertTrue(preview.label.contains("Draft"),
                      "The cell should mark the channel as having a draft; was: \(preview.label)")
        XCTAssertTrue(preview.label.contains("Reply"),
                      "A reply-only draft should preview as Reply; was: \(preview.label)")
    }

    /// A typed reply shows the text, not the word "Reply".
    func test_replyWithText_previewsTheTextOnTheChannelCell() {
        openConversation()

        screen.performContextMenuAction(MenuTitle.reply, on: Convo.messageId(19))
        XCTAssertTrue(screen.waitForActionBar())
        screen.type("typed answer")

        screen.goBack()
        XCTAssertTrue(list.waitUntilLoaded())

        let listCell = list.cell(Convo.channelId)
        XCTAssertTrue(listCell.waitForExistence(timeout: 10))
        let preview = list.message(in: listCell)
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.label.contains("typed answer"),
                      "The typed text is what the user wants to see; was: \(preview.label)")
    }

    // MARK: - Text only (existing behaviour, guarded)

    func test_plainTextDraft_survivesWithoutAnActionBar() {
        openConversation()

        screen.type("just a draft")
        roundTrip()

        XCTAssertTrue(screen.composerText.contains("just a draft"),
                      "The text draft should be restored; was: \(screen.composerText)")
        XCTAssertFalse(screen.hasActionBar, "No action was taken, so no bar should appear")
    }

    func test_sendingClearsTheDraftEntirely() {
        openConversation()

        screen.performContextMenuAction(MenuTitle.reply, on: Convo.messageId(19))
        XCTAssertTrue(screen.waitForActionBar())
        screen.type("sent and gone")
        _ = screen.sendButton.waitForExistence(timeout: 5)
        screen.sendButton.tap()

        roundTrip()

        XCTAssertFalse(screen.hasActionBar, "Sending should clear the reply target")
        XCTAssertTrue(screen.composerText.isEmpty,
                      "Sending should clear the text; was: \(screen.composerText)")
    }

    // MARK: - Helpers

    /// Polls `condition` until true or `timeout` elapses.
    private func waitFor(timeout: TimeInterval = 5,
                         _ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
