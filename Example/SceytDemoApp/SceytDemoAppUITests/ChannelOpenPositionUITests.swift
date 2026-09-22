//
//  ChannelOpenPositionUITests.swift
//  SceytDemoAppUITests
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//
//  Investigates the reported "opened the channel with 2 new messages but the
//  newest one is only partly visible" bug. With a small unread count the
//  unread-separator scroll anchor cannot be honored (2 messages can't fill a
//  screen), so the list must clamp to the very bottom — yet sometimes the
//  newest bubble ends up partially hidden behind the composer.
//
//  Each test isolates one candidate cause:
//    - static:  every unread message is already in the DB before the screen
//      opens (counts 1 / 2 / 3) and nothing arrives while it opens;
//    - racing:  the newest message arrives DURING the open transition
//      (`--uitest-inject-on-open=0`), with and without an armed unread anchor;
//    - settled: the newest message arrives well after the screen settled
//      (control — this path is known-good and covered elsewhere).
//
//  The pre-existing tests assert `isHittable`, which passes for a half-hidden
//  bubble (its centre is still visible) — exactly the reported symptom. These
//  tests instead assert on frames: the newest cell must sit FULLY above the
//  composer.
//

import XCTest

final class ChannelOpenPositionUITests: BaseUITestCase {

    private typealias Convo = ChannelScreen.Conversation

    private var app: XCUIApplication!
    private var list: ChannelListScreen!
    private var screen: ChannelScreen!

    /// Slack for float rounding when comparing settled frames.
    private static let bottomTolerance: CGFloat = 2

    /// Launches the fixture and opens the conversation screen.
    private func openConversation(unreadCount: Int? = nil,
                                  longUnread: Bool = false,
                                  recentUnread: Bool = false,
                                  inject: Bool = false,
                                  injectOnOpenDelayMs: Int? = nil,
                                  growNewestOnOpenDelayMs: Int? = nil,
                                  injectBurstOnOpenDelayMs: Int? = nil,
                                  injectBurstCount: Int = 6,
                                  injectOnKeyboardDelayMs: Int? = nil,
                                  restartObserverOnOpenDelayMs: Int? = nil,
                                  messageStormPairs: Int? = nil,
                                  messageStormIntervalMs: Int = 300,
                                  messageStormStartMs: Int = 1500) {
        app = launchApp(injectionEnabled: inject,
                        conversation: unreadCount == nil,
                        conversationUnreadCount: unreadCount,
                        conversationUnreadLong: longUnread,
                        conversationUnreadRecent: recentUnread,
                        injectOnOpenDelayMs: injectOnOpenDelayMs,
                        growNewestOnOpenDelayMs: growNewestOnOpenDelayMs,
                        injectBurstOnOpenDelayMs: injectBurstOnOpenDelayMs,
                        injectBurstCount: injectBurstCount,
                        injectOnKeyboardDelayMs: injectOnKeyboardDelayMs,
                        restartObserverOnOpenDelayMs: restartObserverOnOpenDelayMs,
                        messageStormPairs: messageStormPairs,
                        messageStormIntervalMs: messageStormIntervalMs,
                        messageStormStartMs: messageStormStartMs)
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

    // MARK: - Static: all unread messages are seeded before the screen opens

    func test_open_oneUnreadSeeded_newestFullyVisible() {
        openConversation(unreadCount: 1)

        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show for 1 unread message")
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(1)),
                            "the single seeded unread message")
    }

    /// The reported scenario: exactly 2 new messages, all present before open.
    /// If this fails, the initial-position math itself is off for small unread
    /// counts (no mid-open race needed).
    func test_open_twoUnreadSeeded_newestFullyVisible() {
        openConversation(unreadCount: 2)

        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show for 2 unread messages")
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest of 2 seeded unread messages")
        XCTAssertTrue(screen.cell(Convo.unreadTailId(1)).isHittable,
                      "The older unread message should be visible above the newest one")
    }

    func test_open_threeUnreadSeeded_newestFullyVisible() {
        openConversation(unreadCount: 3)

        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show for 3 unread messages")
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(3)),
                            "the newest of 3 seeded unread messages")
    }

    /// Like the 2-unread case, but both unread bubbles are several lines tall.
    /// If this fails while the one-liner variant passes, the initial position is
    /// computed from *estimated* (single-line) cell heights: the scroll lands
    /// where a short newest message would end, hiding the bottom of the real,
    /// taller bubble — matching "the second message I see only partly".
    func test_open_twoLongUnreadSeeded_newestFullyVisible() {
        openConversation(unreadCount: 2, longUnread: true)

        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show for 2 long unread messages")
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest of 2 seeded multi-line unread messages")
    }

    /// Like the 2-unread case, but the unread messages are dated *today* while
    /// the history sits on an older day — so a date-separator boundary renders
    /// between the last-read message and the unread tail, as in any real channel
    /// whose new messages arrive days after the old ones. If this fails while
    /// the same-day variant passes, the open position misses the date
    /// separator's height — leaving the newest bubble short by exactly that
    /// amount.
    func test_open_twoUnreadSeededToday_newestFullyVisible() {
        openConversation(unreadCount: 2, recentUnread: true)

        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show for 2 unread messages dated today")
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest of 2 unread messages dated today (date-separator boundary)")
        XCTAssertTrue(screen.cell(Convo.unreadTailId(1)).isHittable,
                      "The older unread message should be visible above the newest one")
    }

    /// Both height deltas stacked: a date-separator boundary AND multi-line
    /// unread bubbles.
    func test_open_twoLongUnreadSeededToday_newestFullyVisible() {
        openConversation(unreadCount: 2, longUnread: true, recentUnread: true)

        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show for 2 long unread messages dated today")
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest of 2 multi-line unread messages dated today")
    }

    // MARK: - Racing: the newest message arrives during the open transition

    /// 1 unread seeded; the second "new message" is injected the moment the
    /// conversation view enters the hierarchy — mid push-transition, before the
    /// initial unread-anchor scroll settles. This is the "the last message
    /// comes during the open" hypothesis, with the unread anchor armed.
    func test_open_oneUnread_secondMessageArrivesDuringOpen_landsAtBottom() {
        openConversation(unreadCount: 1, injectOnOpenDelayMs: 0)

        let injected = cellWithBody(Convo.injectedText)
        XCTAssertTrue(injected.waitForExistence(timeout: 10),
                      "The message injected during the open should appear")
        assertRestsAtBottom(newest: injected,
                            "the message that arrived during the open (unread anchor armed)")
        XCTAssertTrue(screen.cell(Convo.unreadTailId(1)).isHittable,
                      "The seeded unread message should be visible above the injected one")
    }

    /// Delay-sweep variants of the mid-open arrival: the push transition runs
    /// ~350ms, so 150ms lands in the middle of it and 350ms right around
    /// `viewDidAppear` / the initial-scroll settle — the window where a racy
    /// insert is most likely to be missed by the position restore.
    func test_open_oneUnread_secondMessageArrivesMidTransition_landsAtBottom() {
        openConversation(unreadCount: 1, injectOnOpenDelayMs: 150)

        let injected = cellWithBody(Convo.injectedText)
        XCTAssertTrue(injected.waitForExistence(timeout: 10),
                      "The message injected mid-transition should appear")
        assertRestsAtBottom(newest: injected,
                            "the message that arrived mid-transition (150ms)")
    }

    func test_open_oneUnread_secondMessageArrivesAtTransitionEnd_landsAtBottom() {
        openConversation(unreadCount: 1, injectOnOpenDelayMs: 350)

        let injected = cellWithBody(Convo.injectedText)
        XCTAssertTrue(injected.waitForExistence(timeout: 10),
                      "The message injected at transition end should appear")
        assertRestsAtBottom(newest: injected,
                            "the message that arrived at transition end (350ms)")
    }

    /// Same mid-open arrival, but with no unread before the open — so no unread
    /// anchor is armed. Distinguishes "a mid-open insert breaks scroll-to-bottom
    /// in general" from "a mid-open insert fights the unread-separator anchor".
    func test_open_noUnread_messageArrivesDuringOpen_landsAtBottom() {
        openConversation(injectOnOpenDelayMs: 0)

        let injected = cellWithBody(Convo.injectedText)
        XCTAssertTrue(injected.waitForExistence(timeout: 10),
                      "The message injected during the open should appear")
        assertRestsAtBottom(newest: injected,
                            "the message that arrived during the open (no unread anchor)")
    }

    // MARK: - Growth: the newest cell grows in place after the open

    /// 2 unread seeded; ~800ms after the screen starts opening (right after the
    /// initial scroll settles) the newest message's body is rewritten to a long
    /// multi-line text, growing the bottom-most cell in place. This is the
    /// list-level effect of a link preview or attachment thumbnail arriving
    /// asynchronously, or a message edit. If the list doesn't re-anchor to the
    /// bottom, the added height sinks below the composer — "the second message
    /// I see only partly".
    func test_open_twoUnread_newestGrowsAfterOpen_staysFullyVisible() {
        openConversation(unreadCount: 2, growNewestOnOpenDelayMs: 800)

        let grown = cellWithBody(Convo.grownBodyText)
        XCTAssertTrue(grown.waitForExistence(timeout: 10),
                      "The newest message should re-render with the grown body")
        assertRestsAtBottom(newest: grown,
                            "the newest message after it grew in place (post-settle)")
    }

    /// Same growth landing mid-transition, racing the initial scroll.
    func test_open_twoUnread_newestGrowsDuringOpen_staysFullyVisible() {
        openConversation(unreadCount: 2, growNewestOnOpenDelayMs: 150)

        let grown = cellWithBody(Convo.grownBodyText)
        XCTAssertTrue(grown.waitForExistence(timeout: 10),
                      "The newest message should re-render with the grown body")
        assertRestsAtBottom(newest: grown,
                            "the newest message after it grew in place (mid-transition)")
    }

    // MARK: - Control: the message arrives after the screen has settled

    /// The injection fires ~2s after the conversation view appears, when the
    /// open transition and the initial scroll are long done. A failure here
    /// (with the passes above) would point at the plain insert-at-bottom path
    /// rather than anything open-specific.
    func test_open_oneUnread_secondMessageArrivesAfterSettle_landsAtBottom() {
        openConversation(unreadCount: 1, injectOnOpenDelayMs: 2000)

        let injected = cellWithBody(Convo.injectedText)
        XCTAssertTrue(injected.waitForExistence(timeout: 15),
                      "The message injected after settling should appear")
        assertRestsAtBottom(newest: injected,
                            "the message that arrived after the screen settled")
    }

    // MARK: - Rapid traffic at the bottom

    /// The user sits at the bottom rapidly alternating sends and receives: each
    /// round types + sends a message and taps the incoming-message injector
    /// immediately after — so the second insert regularly lands while the first
    /// batch is still animating (exercising the parked-diff single-flight
    /// queue). The viewport must stay glued to the bottom the whole time: after
    /// every round, no message cell may extend below the composer. Runs on the
    /// 2-unread open so the unread scroll anchor is armed — the worst-case
    /// state from the partially-hidden-newest-message bug.
    func test_atBottom_rapidSendAndReceive_alwaysStaysAtBottom() {
        openConversation(unreadCount: 2, inject: true)

        XCTAssertTrue(screen.injectIncomingButton.waitForExistence(timeout: 10),
                      "The floating injector button should be installed in inject mode")
        // Settle the open position before starting the storm.
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest unread message on open")

        let injectedBodies = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND label == %@",
                        ChannelScreen.AID.body, Convo.injectedText))

        for round in 1...3 {
            let sent = "Rapid send \(round)"
            screen.send(sent)
            // Fire the receive right behind the send, without waiting for the
            // send's insert animation to finish.
            screen.injectIncomingButton.tap()

            XCTAssertTrue(waitFor(timeout: 10) { self.cellWithBody(sent).exists },
                          "Round \(round): the sent message should appear")
            XCTAssertTrue(waitFor(timeout: 10) { injectedBodies.count == round },
                          "Round \(round): the received message should appear "
                            + "(expected \(round) injected, saw \(injectedBodies.count))")
            assertNoMessageCellBelowComposer("after send+receive round \(round)")
        }
    }

    // MARK: - At-bottom stickiness: rapid traffic must never leave the bottom
    //
    // Invariant under test: while the viewport rests at the bottom, it REMAINS
    // at the bottom no matter how quickly messages are received and sent. The
    // reported violation: opening on unread and receiving/sending rapidly
    // sometimes yanks the scroll position back to the "New messages" separator.

    /// A server-sync-shaped batch: several messages landing in ONE database
    /// transaction, so the list update carries a multi-insert diff instead of
    /// the usual single insert. It fires 150ms after the conversation view
    /// enters the hierarchy — after the initial unread-anchor scroll has
    /// clamped to the bottom, but early enough to be the FIRST list update
    /// after the open (before the mark-displayed write disarms the unread-open
    /// state ~0.5s in) — exactly what opening a busy channel looks like. The
    /// viewport rests at the bottom when the batch arrives — it must stay
    /// there. The reported bug: the list re-asserts the unread-separator
    /// scroll position instead, parking the viewport at "New messages" with
    /// the batch off-screen below.
    func test_open_unread_burstArrivesAtBottom_staysAtBottom() {
        openConversation(unreadCount: 2, injectBurstOnOpenDelayMs: 150, injectBurstCount: 8)

        assertViewportAtBottomShowing(Convo.burstText(8),
                                      "the newest message of the 8-message burst")
        assertNoMessageCellBelowComposer("after the burst landed")
    }

    /// One incoming message lands ~100ms into the keyboard's slide-up animation
    /// (the user tapped the composer to type just as traffic arrives). The
    /// keyboard animates the list's insets, so the insert is processed while the
    /// offset-vs-inset bottom check is transiently unreliable — the window where
    /// the unread open's scroll anchors can survive and start holding the
    /// viewport to the last-read message. Three follow-up receives compound any
    /// surviving anchor; the viewport must stay glued to the bottom throughout.
    func test_open_unread_receiveDuringKeyboardShow_thenMore_staysAtBottom() {
        openConversation(unreadCount: 2, inject: true, injectOnKeyboardDelayMs: 100)

        XCTAssertTrue(screen.injectIncomingButton.waitForExistence(timeout: 10),
                      "The floating injector button should be installed in inject mode")
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest unread message on open")

        let injectedBodies = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND label == %@",
                        ChannelScreen.AID.body, Convo.injectedText))

        // Present the keyboard; the harness injects 100ms into its animation.
        screen.inputField.tap()
        XCTAssertTrue(waitFor(timeout: 10) { injectedBodies.count >= 1 },
                      "The message injected during the keyboard animation should appear")
        assertNoMessageCellBelowComposer("after the mid-keyboard-animation receive")

        // Enough follow-ups that the content since the separator outgrows even
        // the keyboard-shrunk viewport — only then is "the separator must be
        // off-screen" a valid at-bottom check (with a handful of short
        // messages the separator is legitimately still visible at the top).
        // Arrival is detected by the bottom-most cell's identity changing, not
        // by counting bodies: the injected bodies are identical and once they
        // overflow the viewport the older ones derealize, so a count plateaus.
        for round in 2...10 {
            let bottomBefore = bottomMostMessageCellId()
            screen.injectIncomingButton.tap()
            XCTAssertTrue(waitFor(timeout: 10) { self.bottomMostMessageCellId() != bottomBefore },
                          "Follow-up receive \(round) should land at the bottom")
            assertNoMessageCellBelowComposer("after follow-up receive \(round)")
        }
        assertSeparatorNotInViewport("after 10 receives while sitting at the bottom")
    }

    /// The reported scenario end-to-end: the channel is already busy when it is
    /// opened on unread — a send+receive pair lands every 250ms through the DB
    /// pipeline starting 200ms after the open (the storm, not a marker write,
    /// is the first update the screen sees) — and the user types and sends
    /// messages the whole time. After every send and once the storm drains,
    /// the viewport must rest at the bottom — never at the "New messages"
    /// separator.
    func test_open_unread_stormWhileSendingRapidly_staysAtBottom() {
        openConversation(unreadCount: 3,
                         messageStormPairs: 12,
                         messageStormIntervalMs: 250,
                         messageStormStartMs: 200)

        for round in 1...3 {
            let sent = "Rapid send \(round)"
            screen.send(sent)
            assertViewportAtBottomShowing(sent, "the just-sent message (round \(round))")
            assertNoMessageCellBelowComposer("after send round \(round)")
        }

        // Let the rest of the storm drain, then the newest storm message must
        // sit at the bottom with the separator long gone off-screen.
        assertViewportAtBottomShowing(Convo.stormReceivedText(12),
                                      "the final storm message",
                                      timeout: 15)
        assertNoMessageCellBelowComposer("after the storm drained")
        assertSeparatorNotInViewport("after the storm drained")
    }

    /// A mid-session message-observer restart — what `createAndSendUserMessage`
    /// does whenever the cached tail lags behind `channel.lastMessage`, which
    /// rapid receive/ACK traffic makes routine. The restart re-delivers an
    /// `isInitial` change event; the view model used to answer it by re-emitting
    /// the unread-anchor scroll with the STALE `lastDisplayedMessageId` from the
    /// open — parking the viewport at the "New messages" separator even though
    /// the user was reading at the bottom (the reported WAAFI regression). The
    /// burst beforehand grows the content below the separator past a screenful,
    /// so a re-anchor would be a real, visible jump rather than a bottom clamp.
    func test_open_unread_observerRestartsMidSession_staysAtBottom() {
        openConversation(unreadCount: 2,
                         injectBurstOnOpenDelayMs: 150,
                         injectBurstCount: 8,
                         restartObserverOnOpenDelayMs: 2500)

        // Settle at the bottom on the burst's newest message first.
        assertViewportAtBottomShowing(Convo.burstText(8),
                                      "the newest burst message before the observer restart")

        // Let the 2.5s-mark restart fire, then the viewport must not have moved.
        _ = waitFor(timeout: 4) { false }
        assertViewportAtBottomShowing(Convo.burstText(8),
                                      "the newest burst message after the mid-session observer restart")
        assertSeparatorNotInViewport("after the mid-session observer restart")
        assertNoMessageCellBelowComposer("after the mid-session observer restart")
    }

    // MARK: - Scroll-down badge

    /// The badge shows `newMessageCount - visible incoming messages`. With a
    /// tall unread block the screen opens at the "New messages" separator, so
    /// several unread messages are already on screen — the badge must report
    /// the remainder, not the raw channel count.
    func test_scrollDownBadge_excludesUnreadAlreadyOnScreen() {
        let seeded = 25
        openConversation(unreadCount: seeded)

        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show for \(seeded) unread messages")
        XCTAssertTrue(screen.scrollDownButton.waitForExistence(timeout: 10),
                      "The scroll-down button should show while unread messages sit below the fold")

        guard let badge = badgeCount() else {
            return XCTFail("The scroll-down button should report its unread count as its value")
        }
        XCTAssertGreaterThan(badge, 0,
                             "Unread messages are still below the fold, so the badge must not be empty")
        XCTAssertLessThan(badge, seeded,
                          "\(seeded) unread were seeded but some are already on screen — "
                              + "the badge must not report the raw channel count")
    }

    /// The subtraction only removes what is on screen RIGHT NOW, so the badge
    /// keeps reporting a remainder while scrolling within the unread block, and
    /// clears once the viewport returns to the newest message.
    func test_scrollDownBadge_staysWhileScrolledUpThenClearsAtBottom() {
        let seeded = 25
        openConversation(unreadCount: seeded)

        XCTAssertTrue(screen.scrollDownButton.waitForExistence(timeout: 10),
                      "The scroll-down button should show while unread messages sit below the fold")
        guard let initial = badgeCount() else {
            return XCTFail("The scroll-down button should report its unread count as its value")
        }
        XCTAssertTrue(initial > 0 && initial < seeded,
                      "The badge should show the unseen remainder, got \(initial) of \(seeded)")

        // The newest message sits at the visual bottom; swiping up moves toward
        // it. The viewport stays inside the all-incoming unread tail, so the
        // visible count — and with it the badge — must not grow.
        screen.collectionView.swipeUp()
        XCTAssertTrue(waitFor(timeout: 5) { (self.badgeCount() ?? 0) <= initial },
                      "Scrolling toward the newest message should never grow the badge past \(initial)")

        if screen.scrollDownButton.exists {
            screen.scrollDownButton.tap()
        }
        XCTAssertTrue(waitFor(timeout: 10) { self.badgeCount() == nil },
                      "The badge should clear once the viewport rests at the newest message")
    }

    // MARK: - Helpers

    /// The scroll-down button's badge, read from its accessibility value.
    /// `nil` when the badge is empty (no unseen unread messages).
    private func badgeCount() -> Int? {
        let button = screen.scrollDownButton
        guard button.exists, let value = button.value as? String
        else { return nil }
        return Int(value)
    }

    /// The message cell whose body text equals `text` — for injected messages,
    /// whose ids are assigned at runtime so they can't be addressed directly.
    private func cellWithBody(_ text: String) -> XCUIElement {
        app.cells.containing(
            NSPredicate(format: "identifier == %@ AND label == %@",
                        ChannelScreen.AID.body, text)
        ).firstMatch
    }

    /// Asserts the list rests at the bottom: `cell` (the newest message) must sit
    /// FULLY above the composer. `isHittable` is deliberately not used — a bubble
    /// half-hidden behind the composer still reports hittable because its centre
    /// is visible, which is exactly the reported bug.
    private func assertRestsAtBottom(newest cell: XCUIElement,
                                     _ name: String,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) {
        XCTAssertTrue(cell.waitForExistence(timeout: 10),
                      "\(name) should exist", file: file, line: line)
        // Give the open/settle scroll animations a chance to finish before
        // declaring the position wrong.
        _ = waitFor(timeout: 6) {
            cell.frame.maxY <= self.screen.inputField.frame.minY + Self.bottomTolerance
        }
        let bottom = cell.frame.maxY
        let composerTop = screen.inputField.frame.minY
        let overlap = bottom - composerTop
        XCTAssertLessThanOrEqual(
            bottom, composerTop + Self.bottomTolerance,
            "\(name) should sit fully above the composer, but its bottom edge is "
                + String(format: "%.1f", overlap)
                + "pt below the composer top (cell \(cell.frame), composer top \(composerTop)) "
                + "— the partially-hidden-newest-message bug",
            file: file, line: line)
    }

    /// Asserts the viewport rests at the bottom showing the message whose body is
    /// `text`. When the message exists but sits below the composer — or is not
    /// realized at all while the "New messages" separator is on screen — the
    /// failure explicitly names the jump-to-separator symptom, distinguishing a
    /// drifted viewport from a message that never arrived.
    private func assertViewportAtBottomShowing(_ text: String,
                                               _ name: String,
                                               timeout: TimeInterval = 10,
                                               file: StaticString = #filePath,
                                               line: UInt = #line) {
        let cell = cellWithBody(text)
        let appeared = cell.waitForExistence(timeout: timeout)
        if !appeared, separatorIsInViewport() {
            XCTFail("\(name): the viewport rests at the 'New messages' separator "
                        + "instead of the bottom — the message is off-screen below "
                        + "(separator frame \(screen.unreadSeparator.frame))",
                    file: file, line: line)
            return
        }
        XCTAssertTrue(appeared, "\(name) should be on screen", file: file, line: line)
        assertRestsAtBottom(newest: cell, name, file: file, line: line)
    }

    /// Whether the "New messages" separator is currently inside the visible
    /// window. Realized-but-offscreen cells still `exist`, so existence alone
    /// is not enough — the frames must intersect.
    private func separatorIsInViewport() -> Bool {
        let separator = screen.unreadSeparator
        guard separator.exists else { return false }
        return separator.frame.intersects(app.windows.firstMatch.frame)
    }

    /// Asserts the "New messages" separator is NOT visible. Only meaningful once
    /// enough traffic has arrived that the separator must be at least a screen
    /// above the bottom — right after open with a small unread count it is
    /// legitimately on screen.
    private func assertSeparatorNotInViewport(_ context: String,
                                              file: StaticString = #filePath,
                                              line: UInt = #line) {
        XCTAssertFalse(
            separatorIsInViewport(),
            "\(context): the 'New messages' separator is inside the viewport "
                + "(frame \(screen.unreadSeparator.frame)) — the scroll position "
                + "moved back to the unread position",
            file: file, line: line)
    }

    /// Identifier of the visually bottom-most realized message cell — the
    /// newest visible message when the viewport rests at the bottom. A fresh
    /// arrival changes it (the new cell materializes at the bottom edge), so
    /// comparing before/after a receive detects arrival without relying on
    /// body text or realized-cell counts.
    private func bottomMostMessageCellId() -> String? {
        messageCellFrames().max(by: { $0.frame.maxY < $1.frame.maxY })?.identifier
    }

    /// One atomic accessibility snapshot of every message cell's
    /// (identifier, frame). Per-element queries (`allElementsBoundByIndex` +
    /// attribute access) re-resolve lazily and throw "No matches found for
    /// Element at index N" when cells churn between binding and access — a
    /// single snapshot walked in memory is immune to that.
    private func messageCellFrames() -> [(identifier: String, frame: CGRect)] {
        guard let root = try? app.snapshot() else { return [] }
        var cells: [(String, CGRect)] = []
        func walk(_ node: XCUIElementSnapshot) {
            if node.elementType == .cell,
               node.identifier.hasPrefix(ChannelScreen.AID.cellRoot) {
                cells.append((node.identifier, node.frame))
            }
            node.children.forEach(walk)
        }
        walk(root)
        return cells
    }

    /// Asserts the viewport rests at the bottom by checking that NO message cell
    /// extends below the composer. Stronger than checking one known-newest cell:
    /// during rapid interleaved sends/receives the newest message alternates, but
    /// a drifted offset always leaves whichever cell is bottom-most clipped by
    /// the composer — and this catches it regardless of ordering.
    private func assertNoMessageCellBelowComposer(_ context: String,
                                                  file: StaticString = #filePath,
                                                  line: UInt = #line) {
        // Let in-flight insert animations settle before measuring.
        _ = waitFor(timeout: 6) {
            let composerTop = self.screen.inputField.frame.minY
            return self.messageCellFrames().allSatisfy {
                $0.frame.maxY <= composerTop + Self.bottomTolerance
            }
        }
        let composerTop = screen.inputField.frame.minY
        for cell in messageCellFrames() {
            let overlap = cell.frame.maxY - composerTop
            XCTAssertLessThanOrEqual(
                cell.frame.maxY, composerTop + Self.bottomTolerance,
                "\(context): cell \(cell.identifier) extends "
                    + String(format: "%.1f", overlap)
                    + "pt below the composer top — the viewport drifted off the bottom",
                file: file, line: line)
        }
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
