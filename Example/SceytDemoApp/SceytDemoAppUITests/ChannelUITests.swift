//
//  ChannelUITests.swift
//  SceytDemoAppUITests
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//
//  Black-box UI tests for the open-channel (conversation) screen driven by
//  `ChannelViewController`. The app is launched in `--uitest --uitest-conversation`
//  mode, which skips login/connection and seeds a single channel (id 100,
//  "UITest Chat") with a fixed ~19-message history (see `UITestSupport` in the app
//  target). `--uitest-conversation-unread` additionally marks the last 3 messages
//  unread so the "New messages" separator renders.
//
//  Message ids are fixed (`sceyt_chat_channel_message_cell.<id>`), where id = 100 * 10_000 + index:
//    index 1   "Start of the conversation"   — oldest, at the top
//    index 16  "This is the last read message" — unread-separator anchor
//    index 18  "My outgoing reply"           — outgoing (right-aligned)
//    index 19  "This is the newest message"  — newest, at the visual bottom
//

import XCTest

final class ChannelUITests: BaseUITestCase {

    private typealias Convo = ChannelScreen.Conversation

    private var app: XCUIApplication!
    private var list: ChannelListScreen!
    private var screen: ChannelScreen!

    /// Launches the conversation fixture and opens the channel screen.
    private func openConversation(unread: Bool = false, inject: Bool = false) {
        app = launchApp(injectionEnabled: inject,
                        conversation: !unread,
                        conversationUnread: unread)
        list = ChannelListScreen(app: app)
        screen = ChannelScreen(app: app)

        XCTAssertTrue(list.waitUntilLoaded(), "The channel list should load")
        let listCell = list.cell(Convo.channelId)
        XCTAssertTrue(listCell.waitForExistence(timeout: 10),
                      "The seeded conversation channel should appear in the list")
        listCell.tap()

        XCTAssertTrue(screen.waitUntilReady(), "The channel composer should appear")
        XCTAssertTrue(screen.collectionView.waitForExistence(timeout: 10),
                      "The message list should appear")
    }

    // MARK: - Opening / header

    func test_openChannel_showsComposerTitleAndMessages() {
        openConversation()

        XCTAssertTrue(screen.inputField.exists, "The message composer should be present")

        XCTAssertTrue(screen.title.waitForExistence(timeout: 5), "The header title should show")
        XCTAssertTrue(screen.title.label.contains(Convo.subject),
                      "The header should show the channel subject; was: \(screen.title.label)")

        // The newest message renders at the bottom on open.
        XCTAssertTrue(screen.cell(Convo.lastId).waitForExistence(timeout: 10),
                      "The newest message cell should be visible on open")
        XCTAssertEqual(screen.body(in: screen.cell(Convo.lastId)).label, Convo.lastText,
                       "The newest cell should render the seeded body text")
    }

    // MARK: - Ordering (inverted list)

    func test_messageOrder_newestSitsBelowOlder() {
        openConversation()

        let newest = screen.cell(Convo.lastId)      // index 19
        let older = screen.cell(Convo.outgoingId)   // index 18
        XCTAssertTrue(newest.waitForExistence(timeout: 10))
        XCTAssertTrue(older.waitForExistence(timeout: 5))

        // In the mirrored (inverted) list the newer message is visually lower —
        // i.e. it has a larger minY on screen.
        XCTAssertGreaterThan(newest.frame.minY, older.frame.minY,
                             "The newest message should sit below the older one")
    }

    // MARK: - Incoming vs outgoing layout

    func test_incomingAndOutgoing_alignToOppositeSides() {
        openConversation()

        let outgoing = screen.cell(Convo.outgoingId)   // index 18 — mine
        let incoming = screen.cell(Convo.lastId)        // index 19 — from Bob
        XCTAssertTrue(outgoing.waitForExistence(timeout: 10))
        XCTAssertTrue(incoming.waitForExistence(timeout: 5))

        let outBody = screen.body(in: outgoing)
        let inBody = screen.body(in: incoming)
        XCTAssertTrue(outBody.exists, "Outgoing body should render")
        XCTAssertTrue(inBody.exists, "Incoming body should render")

        // Outgoing messages hug the right edge, incoming ones the left.
        let midX = app.windows.firstMatch.frame.midX
        XCTAssertGreaterThan(outBody.frame.midX, midX, "Outgoing message should be right-aligned")
        XCTAssertLessThan(inBody.frame.midX, midX, "Incoming message should be left-aligned")
        XCTAssertGreaterThan(outBody.frame.midX, inBody.frame.midX,
                             "Outgoing should sit further right than incoming")
    }

    // MARK: - Sending

    func test_sendMessage_appendsToListAndClearsComposer() {
        openConversation()

        let sent = "Hello from the channel UI test"
        screen.send(sent)

        // The composer clears once the message is committed (send button hides).
        XCTAssertTrue(waitFor { !self.screen.sendButton.exists },
                      "The composer should clear after sending")

        // The sent text shows up as a new message body in the list.
        XCTAssertTrue(waitFor(timeout: 10) { self.messageBodyExists(sent) },
                      "The sent message should appear in the conversation")
    }

    /// A long message should grow the composer, the message list should stay
    /// pinned to the bottom (the newest message stays visible above the grown
    /// composer/keyboard), and sending should reset the composer and land the
    /// message at the bottom.
    func test_longText_growsComposer_keepsListAtBottom_andResetsOnSend() {
        openConversation()

        let newest = screen.cell(Convo.lastId)
        XCTAssertTrue(newest.waitForExistence(timeout: 10))
        XCTAssertTrue(newest.isHittable, "The newest message should be visible at the bottom on open")

        let collapsedHeight = screen.inputField.frame.height
        let newestBottomBefore = newest.frame.maxY

        let longText = "This is a deliberately long message written so the composer input text view has to wrap across several lines and grow taller than a single line before it is sent."
        screen.inputField.tap()
        screen.inputField.typeText(longText)

        // 1. The composer grows to fit the wrapped text.
        let grownHeight = screen.inputField.frame.height
        XCTAssertGreaterThan(grownHeight, collapsedHeight + 10,
                             "The composer should grow taller for a multi-line message (was \(collapsedHeight), now \(grownHeight))")

        // 2. The list stays anchored to the bottom: the newest message is still
        //    visible (not covered by the grown composer/keyboard) and has been
        //    pushed up to sit above the composer.
        XCTAssertTrue(newest.isHittable,
                      "The newest message should remain visible while the composer grows")
        XCTAssertLessThan(newest.frame.maxY, newestBottomBefore,
                          "The list should re-anchor to the bottom as the composer/keyboard grow")

        // 3. Send it.
        XCTAssertTrue(screen.sendButton.waitForExistence(timeout: 5),
                      "The send button should appear once text is entered")
        screen.sendButton.tap()

        // The composer clears and collapses back to its single-line height.
        XCTAssertTrue(waitFor { !self.screen.sendButton.exists },
                      "The composer should clear after sending")
        XCTAssertTrue(waitFor { self.screen.inputField.frame.height <= collapsedHeight + 6 },
                      "The composer should collapse back to its single-line height after sending")

        // The sent long message lands at the bottom and is visible.
        XCTAssertTrue(waitFor(timeout: 10) { self.messageBodyExists(longText) },
                      "The sent long message should appear in the conversation")
        let sentBody = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", ChannelScreen.AID.body, longText)
        ).firstMatch
        XCTAssertTrue(waitFor(timeout: 5) { sentBody.isHittable },
                      "The sent message should be visible at the bottom of the list")
    }

    /// Regression: opening a channel on the unread separator arms a scroll
    /// anchor (`pinnedScrollMessageId`) on the last-read message, and nothing
    /// released it while the user was reading at the bottom. Any newest-edge
    /// insert — an incoming message or one just sent — then triggered the batch
    /// completion's pin restore, which held the last-read message still and
    /// pushed the new bubble below the visual bottom, hidden behind the
    /// composer/keyboard. Covers both directions: receive, then send.
    func test_unreadOpen_newMessagesLandAtBottom() {
        openConversation(unread: true, inject: true)

        // Precondition: the unread fixture shows the separator (the scroll
        // anchor is armed) and the list rests at the bottom.
        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should appear for the unread fixture")

        // 1. Receive a message while resting at the bottom.
        XCTAssertTrue(screen.injectIncomingButton.waitForExistence(timeout: 10),
                      "The floating injector button should be installed in inject mode")
        screen.injectIncomingButton.tap()
        XCTAssertTrue(waitFor(timeout: 10) { self.messageBodyExists(Convo.injectedText) },
                      "The received message should appear in the conversation")
        let received = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", ChannelScreen.AID.body, Convo.injectedText)
        ).firstMatch
        XCTAssertTrue(waitFor(timeout: 5) { received.isHittable },
                      "The received message should be visible at the bottom, not hidden behind the composer")

        // 2. Send a message (keyboard open) — the originally reported flow.
        let sent = "Sent while opened on unread"
        screen.send(sent)

        XCTAssertTrue(waitFor { !self.screen.sendButton.exists },
                      "The composer should clear after sending")
        XCTAssertTrue(waitFor(timeout: 10) { self.messageBodyExists(sent) },
                      "The sent message should appear in the conversation")
        let sentBody = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", ChannelScreen.AID.body, sent)
        ).firstMatch
        XCTAssertTrue(waitFor(timeout: 5) { sentBody.isHittable },
                      "The sent message should be visible at the bottom, not hidden behind the composer")
    }

    // MARK: - Scroll-to-bottom button

    func test_scrollDownButton_revealsThenReturnsToBottom() {
        openConversation()

        // Scroll away from the bottom to surface the scroll-down button.
        XCTAssertTrue(revealScrollDownButton(), "The scroll-down button should appear when scrolled up")
        XCTAssertTrue(screen.scrollDownButton.isHittable)

        // Tapping it jumps back to the newest message.
        screen.scrollDownButton.tap()
        XCTAssertTrue(waitFor(timeout: 10) { self.screen.cell(Convo.lastId).isHittable },
                      "Tapping the scroll-down button should return to the newest message")
    }

    // MARK: - Unread separator

    func test_unreadSeparator_showsWhenOpeningWithUnread() {
        openConversation(unread: true)

        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should appear for a channel with unread messages")
        XCTAssertTrue(screen.cell(Convo.lastReadId).exists,
                      "The last-read message (the separator anchor) should be present")
    }

    func test_unreadSeparator_absentWithoutUnread() {
        openConversation()
        XCTAssertFalse(screen.unreadSeparator.waitForExistence(timeout: 3),
                       "No 'New messages' separator should show when there are no unread messages")
    }

    // MARK: - Reply

    func test_tapReplyPreview_scrollsToParentMessage() {
        openConversation()

        // The reply message (an inline quote) is visible near the bottom on open.
        let reply = screen.cell(Convo.replyMessageId)
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        XCTAssertTrue(reply.isHittable, "The reply message should be visible on open")

        // The quoted (parent) message is the very first one — off-screen at the top.
        let parent = screen.cell(Convo.repliedToId)
        XCTAssertFalse(parent.isHittable,
                       "The quoted message should be off-screen before tapping the reply preview")

        // Tap the quoted preview.
        let preview = screen.replyView(in: reply)
        XCTAssertTrue(preview.waitForExistence(timeout: 5),
                      "The reply message should render a quoted preview")
        preview.tap()

        // The conversation scrolls up to the original message.
        XCTAssertTrue(waitFor(timeout: 10) { parent.isHittable },
                      "Tapping the reply preview should scroll to the quoted message")
        XCTAssertEqual(screen.body(in: parent).label, Convo.repliedToText,
                       "The quoted message body should be shown after scrolling")
    }

    // MARK: - Navigation

    func test_backButton_returnsToChannelList() {
        openConversation()
        screen.goBack()
        XCTAssertTrue(waitFor { self.list.table.isHittable },
                      "Tapping back should return to the channel list")
    }

    // MARK: - Helpers

    /// Whether a message cell with the given body text is currently rendered.
    private func messageBodyExists(_ text: String) -> Bool {
        let predicate = NSPredicate(format: "identifier == %@ AND label == %@",
                                    ChannelScreen.AID.body, text)
        return app.staticTexts.matching(predicate).firstMatch.exists
    }

    /// Scrolls the message list (in either direction, to be robust to the mirrored
    /// layout) until the scroll-down button appears.
    private func revealScrollDownButton() -> Bool {
        if screen.scrollDownButton.exists { return true }
        for _ in 0..<4 {
            screen.collectionView.swipeDown()
            if screen.scrollDownButton.waitForExistence(timeout: 1) { return true }
        }
        for _ in 0..<4 {
            screen.collectionView.swipeUp()
            if screen.scrollDownButton.waitForExistence(timeout: 1) { return true }
        }
        return screen.scrollDownButton.exists
    }

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
