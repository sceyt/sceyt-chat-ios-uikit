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
//  `--uitest-conversation-tail-count=N` appends N read incoming messages after
//  index 19 (ids 30+1…30+N, "Tail n"), which moves the reply at index 18 away from
//  the bottom — see the reply return-jump tests.
//

import XCTest

final class ChannelUITests: BaseUITestCase {

    private typealias Convo = ChannelScreen.Conversation

    private var app: XCUIApplication!
    private var list: ChannelListScreen!
    private var screen: ChannelScreen!

    /// Launches the conversation fixture and opens the channel screen.
    private func openConversation(unread: Bool = false,
                                  inject: Bool = false,
                                  tailCount: Int? = nil,
                                  fetchLimit: Int? = nil,
                                  nearLoadDelayMs: Int? = nil) {
        app = launchApp(injectionEnabled: inject,
                        conversation: !unread,
                        conversationUnread: unread,
                        conversationTailCount: tailCount,
                        messagesFetchLimit: fetchLimit,
                        nearLoadLocalDelayMs: nearLoadDelayMs)
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

    /// The reported bug: after a reply preview takes the user up to the quoted
    /// message, the scroll-down button jumped all the way to the newest message
    /// instead of returning them to the reply they came from.
    ///
    /// Needs the read tail: in the plain fixture the reply (index 18) and the newest
    /// message (index 19) are neighbours, so both behaviours land on one screen and
    /// the assertion below would pass either way.
    func test_scrollDownAfterReplyJump_returnsToReplyNotBottom() {
        openConversation(tailCount: Self.replyReturnTailCount)

        jumpToQuotedMessageFromReply()

        // Back to the reply — not to the newest message.
        XCTAssertTrue(screen.scrollDownButton.waitForExistence(timeout: 10),
                      "The scroll-down button should be showing while parked on the quoted message")
        screen.scrollDownButton.tap()
        assertReturnedToReply()

        // The anchor is consumed, so a second tap means "go to the newest message"
        // and the user is never stranded up in the history.
        XCTAssertTrue(waitFor(timeout: 10) { self.screen.scrollDownButton.isHittable },
                      "The scroll-down button should still be showing at the reply")
        screen.scrollDownButton.tap()
        XCTAssertTrue(waitFor(timeout: 10) { self.newestTailCell.isHittable },
                      "A second tap should fall through to the newest message")
    }

    /// The return target has to survive the user nudging the list while they read the
    /// quoted message — releasing it on any drag would put the button straight back
    /// to jumping to the bottom.
    func test_scrollDownAfterReplyJump_survivesManualScroll() {
        openConversation(tailCount: Self.replyReturnTailCount)

        jumpToQuotedMessageFromReply()

        // A nudge, not a flick: it has to leave the list well short of the newest
        // message, which is where the return target is legitimately dropped.
        screen.nudgeMessageList(dy: -120)

        XCTAssertTrue(screen.scrollDownButton.waitForExistence(timeout: 10),
                      "The scroll-down button should be showing after the nudge")
        screen.scrollDownButton.tap()
        assertReturnedToReply()
    }

    // MARK: - Reply, quoted parent outside the loaded window

    /// The three tests below drive the path a jump takes when the quoted parent is *not*
    /// in the loaded window: a server round trip (answered locally after
    /// `Self.nearLoadDelayMs`), then an observer restart around the parent. Every
    /// rapid-tap bug lived on that path; with the default 50-message window the whole
    /// fixture is cached and none of it could be reached.

    /// A return tap right after the forward jump landed, inside the second the landing
    /// keeps its target armed for the highlight. That landing's delayed reset used to
    /// wipe the return jump's freshly armed target, so the restart's first change event
    /// had nothing to scroll to and the list stayed wherever the new window put it.
    func test_returnTapInsideHighlightGrace_returnsToReply() {
        openLoaderReplyFixture()

        jumpToQuotedMessageFromReply()

        XCTAssertTrue(screen.scrollDownButton.waitForExistence(timeout: 5),
                      "The scroll-down button should be showing while parked on the quoted message")
        // No settling: the tap has to land well inside the landing's 1 s grace.
        screen.scrollDownButton.tap()
        assertReturnedToReply(timeout: Self.loaderJumpTimeout)
    }

    /// A return tap before the forward jump has even landed. The reply is still in the
    /// window, so the return is an immediate local scroll — and the forward jump, still
    /// loading its parent, must not land on it afterwards.
    func test_returnTapBeforeForwardJumpLands_staysOnReply() {
        openLoaderReplyFixture()

        let reply = scrollReplyIntoView()
        let preview = screen.replyView(in: reply)
        XCTAssertTrue(preview.waitForExistence(timeout: 5),
                      "The reply message should render a quoted preview")
        preview.tap()
        XCTAssertTrue(screen.scrollDownButton.waitForExistence(timeout: 5),
                      "The scroll-down button should be showing next to the reply")
        screen.scrollDownButton.tap()

        // Give the superseded forward jump every chance to land wrongly.
        XCTAssertFalse(waitFor(timeout: Self.loaderJumpTimeout) {
            self.screen.cell(Convo.repliedToId).isHittable
        }, "The forward jump was superseded by the return tap and must not land on the quoted message")
        XCTAssertTrue(reply.isHittable,
                      "The list should have stayed on the reply; hittable cells: \(hittableMessageCellIds())")
    }

    /// Two quick taps on the same quoted preview. The server query is single-flight, so
    /// the second tap used to be rejected as "query in progress" and — worse — release
    /// the first tap's target while its load was still running, leaving the list on an
    /// unscrolled window and the user with an error alert. Now the second tap waits for
    /// the first load and the parent is reached exactly once, with no alert.
    func test_doubleTapReplyPreview_landsOnParentOnce() {
        openLoaderReplyFixture()

        let reply = scrollReplyIntoView()
        let preview = screen.replyView(in: reply)
        XCTAssertTrue(preview.waitForExistence(timeout: 5),
                      "The reply message should render a quoted preview")
        // Two taps on the same screen point, captured once: `XCUIElement.tap()` re-resolves
        // the element each time, and once the first load lands the reply is outside the
        // restarted window — the second tap would then fail to find it rather than race it.
        let point = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: preview.frame.midX, dy: preview.frame.midY))
        point.tap()
        point.tap()

        XCTAssertTrue(waitFor(timeout: Self.loaderJumpTimeout) {
            self.screen.cell(Convo.repliedToId).isHittable
        }, "Both taps asked for the quoted message; it should be reached; hittable cells: \(hittableMessageCellIds())")
        XCTAssertFalse(app.alerts.firstMatch.exists,
                       "A superseded tap is not an error the user should see")
    }

    // MARK: - Navigation

    func test_backButton_returnsToChannelList() {
        openConversation()
        screen.goBack()
        XCTAssertTrue(waitFor { self.list.table.isHittable },
                      "Tapping back should return to the channel list")
    }

    // MARK: - Helpers (reply return-jump)

    /// Enough read messages after the reply that a `.centeredVertically` scroll to it
    /// cannot clamp to the bottom, while still being only a few swipes away.
    private static let replyReturnTailCount = 15

    /// Window size for the loader-path tests: 19 seeded messages + the 15-message tail
    /// is 34, so a 20-message window opens on the tail with the reply (index 18) inside
    /// it and the quoted parent (index 1) outside — every jump to the parent, and every
    /// return from the parent's window to the reply, has to go through the loader.
    private static let loaderFetchLimit = 20

    /// How long the local stand-in for the "load messages around X" request takes.
    /// Long enough that a second tap reliably arrives while the first is in flight — an
    /// XCUITest tap can take the better part of a second to resolve and settle — and that
    /// a return tap after a landing reliably falls inside the landing's 1 s grace.
    private static let nearLoadDelayMs = 3000

    /// A jump through the loader takes `nearLoadDelayMs` plus the restart; a deferred one
    /// takes two loads.
    private static let loaderJumpTimeout: TimeInterval = 12

    private var newestTailCell: XCUIElement { screen.cell(Convo.tailId(Self.replyReturnTailCount)) }

    private func openLoaderReplyFixture() {
        openConversation(tailCount: Self.replyReturnTailCount,
                         fetchLimit: Self.loaderFetchLimit,
                         nearLoadDelayMs: Self.nearLoadDelayMs)
    }

    /// Scrolls up from the tail until the reply is on screen.
    @discardableResult
    private func scrollReplyIntoView() -> XCUIElement {
        let reply = screen.cell(Convo.replyMessageId)
        XCTAssertTrue(waitFor(timeout: 15) {
            if reply.exists, reply.isHittable { return true }
            self.screen.collectionView.swipeDown()
            return false
        }, "The reply message should be reachable by scrolling up from the tail")
        return reply
    }

    /// Scrolls the reply into view, taps its quoted preview, and waits for the jump to
    /// the quoted message to land — the starting state the return-jump tests assert from.
    private func jumpToQuotedMessageFromReply() {
        let reply = scrollReplyIntoView()

        let preview = screen.replyView(in: reply)
        XCTAssertTrue(preview.waitForExistence(timeout: 5),
                      "The reply message should render a quoted preview")
        preview.tap()

        XCTAssertTrue(waitFor(timeout: 15) { self.screen.cell(Convo.repliedToId).isHittable },
                      "Tapping the reply preview should scroll to the quoted message")
    }

    /// Ids of the message cells the user can actually reach, for failure messages.
    private func hittableMessageCellIds() -> String {
        let cells = app.cells.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", ChannelScreen.AID.cellRoot + ".")
        )
        let ids = (0..<cells.count)
            .map { cells.element(boundBy: $0) }
            .filter { $0.isHittable }
            .map { $0.identifier.replacingOccurrences(of: ChannelScreen.AID.cellRoot + ".", with: "") }
        return ids.isEmpty ? "<none>" : ids.joined(separator: ", ")
    }

    /// The assertion the bug fails: the button lands back on the reply, and *not* on the
    /// newest message. The second half is what separates the fix from a jump to the bottom.
    private func assertReturnedToReply(timeout: TimeInterval = 10) {
        XCTAssertTrue(waitFor(timeout: timeout) { self.screen.cell(Convo.replyMessageId).isHittable },
                      "The scroll-down button should return to the reply that was tapped; "
                      + "hittable cells: \(hittableMessageCellIds())")
        XCTAssertFalse(newestTailCell.isHittable,
                       "It should stop at the reply, not carry on to the newest message")
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
