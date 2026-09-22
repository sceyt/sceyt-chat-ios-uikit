//
//  ChannelMultiDeviceSyncUITests.swift
//  SceytDemoAppUITests
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//
//  Reproduces the multi-device scroll jump: the same account is active on iOS
//  and Web. The Web client sends several messages, then a remote participant
//  sends more, and the (terminated) iOS app is opened from one of the received
//  messages' push notifications. The channel opens showing the received
//  messages — but the Web-sent messages are not in the local store yet; they
//  arrive moments later through a server sync and sort in ABOVE the received
//  block (they are older). Reported bug: the viewport initially rests on the
//  received messages, then JUMPS to the messages previously sent from Web —
//  reliably when the user has already dragged the list a little by finger.
//
//  The harness models the sequence deterministically:
//    - the seeded unread tail plays the received messages (present at open,
//      like a push-announced tail);
//    - the web-sync injection (`ChannelScreen.Conversation.webSyncText`)
//      plays the late sync page: OUTGOING messages inserted in ONE database
//      transaction, dated BETWEEN the last-read message and the received
//      block, so they land in the middle of the loaded history;
//    - the `restart` flavor follows the insert with the observer-window
//      recalculation the real sync pipeline performs (re-delivers an
//      `isInitial` change event) — the racier, truer-to-production shape.
//
//  Invariant under test: content arriving ABOVE the viewport must never move
//  the viewport. Whatever the update's plumbing (plain diff or observer
//  restart), the messages the user is looking at must keep their screen
//  position — no jump up to the web-sent block, no yank down to the bottom.
//

import XCTest

final class ChannelMultiDeviceSyncUITests: BaseUITestCase {

    private typealias Convo = ChannelScreen.Conversation

    private var app: XCUIApplication!
    private var list: ChannelListScreen!
    private var screen: ChannelScreen!

    /// Slack for float rounding when comparing settled frames.
    private static let bottomTolerance: CGFloat = 2

    /// How far the anchored message may drift after a batch lands above the
    /// viewport. A real jump moves the content by the web block's height
    /// (several hundred points) or to the bottom (a screenful) — 12pt of
    /// settle noise is safely below either.
    private static let anchorTolerance: CGFloat = 12

    /// Launches the fixture and opens the conversation screen.
    private func openConversation(unreadCount: Int,
                                  longUnread: Bool = false,
                                  webSyncButtonCount: Int? = nil,
                                  webSyncButtonRestart: Bool = false,
                                  webSyncOnOpenDelayMs: Int? = nil,
                                  webSyncOnOpenCount: Int = 8,
                                  webSyncOnOpenRestart: Bool = false,
                                  webSyncSeededCount: Int? = nil) {
        app = launchApp(conversationUnreadCount: unreadCount,
                        conversationUnreadLong: longUnread,
                        webSyncButtonCount: webSyncButtonCount,
                        webSyncButtonRestart: webSyncButtonRestart,
                        webSyncOnOpenDelayMs: webSyncOnOpenDelayMs,
                        webSyncOnOpenCount: webSyncOnOpenCount,
                        webSyncOnOpenRestart: webSyncOnOpenRestart,
                        webSyncSeededCount: webSyncSeededCount)
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

    // MARK: - The reported repro: drag a little, then the Web messages arrive

    /// The user's exact sequence. A tall unread tail (12 multi-line received
    /// messages) opens the screen at the "New messages" separator; the user
    /// drags the list a little (which disarms the unread-open anchors, as a
    /// real reading interaction does); THEN the Web-sent batch lands above the
    /// viewport as one database transaction. The message the user was looking
    /// at must stay exactly where it was.
    func test_open_unread_dragSlightly_thenWebBatchArrives_viewportDoesNotJump() {
        openConversation(unreadCount: 12, longUnread: true, webSyncButtonCount: 6)
        assertNoJumpAfterWebSync()
    }

    /// Same sequence, but the insert is followed by the observer-window
    /// recalculation the real sync pipeline performs after storing a page
    /// (an `isInitial` redelivery). This is the truest model of the reported
    /// production scenario — sync never delivers a bare database write.
    func test_open_unread_dragSlightly_thenWebBatchWithSyncRecalc_viewportDoesNotJump() {
        openConversation(unreadCount: 12, longUnread: true,
                         webSyncButtonCount: 6, webSyncButtonRestart: true)
        assertNoJumpAfterWebSync()
    }

    /// Shared body of the two drag-first repros: settle at the separator open
    /// position, drag slightly, snapshot the mid-viewport anchor message, fire
    /// the web sync, and require the anchor (and the whole viewport) to hold.
    private func assertNoJumpAfterWebSync(file: StaticString = #filePath,
                                          line: UInt = #line) {
        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show on open",
                      file: file, line: line)
        XCTAssertTrue(screen.injectWebSyncButton.waitForExistence(timeout: 10),
                      "The floating web-sync injector should be installed",
                      file: file, line: line)
        waitUntilListSettles(file: file, line: line)

        // "Moved the list a little with a finger": a slow, short, momentum-free
        // drag toward the newer messages. It takes the separator (and with it
        // the spot where the web block will be inserted) just above the
        // viewport's top edge, and — like any real drag — clears the unread
        // open anchors.
        dragListSlightly()
        waitUntilListSettles(file: file, line: line)

        XCTAssertFalse(separatorIsInViewport(),
                       "After the small drag the 'New messages' separator should "
                           + "sit just above the viewport (got frame "
                           + "\(screen.unreadSeparator.frame)) — the insert point "
                           + "must be off-screen for the assertion to be meaningful",
                       file: file, line: line)

        guard let anchor = midViewportMessageCell() else {
            return XCTFail("A message cell should be visible mid-viewport after the drag",
                           file: file, line: line)
        }

        tapWebSyncButtonAndVerifyLanded(file: file, line: line)

        // No user-visible signal marks a *correct* application of the batch
        // (it lands entirely above the viewport), so give the diff — and the
        // sync-recalc flavor's observer restart (fires 300ms after the
        // insert) — ample time to apply before measuring. A wrong application
        // (a jump) would also happen well within this window.
        wait(seconds: 3)

        let anchorAfter = app.cells[anchor.identifier]
        XCTAssertTrue(
            anchorAfter.exists,
            "The message the user was reading (\(anchor.identifier), was at "
                + "\(anchor.frame)) is gone from the realized cells after the "
                + "web-sent batch arrived — the viewport jumped away from it. "
                + viewportDescription(),
            file: file, line: line)
        guard anchorAfter.exists else { return }
        let drift = anchorAfter.frame.midY - anchor.frame.midY
        XCTAssertLessThanOrEqual(
            abs(drift), Self.anchorTolerance,
            "The web-sent batch arrived above the viewport, but the message the "
                + "user was reading moved \(String(format: "%.1f", drift))pt "
                + "(from \(anchor.frame) to \(anchorAfter.frame)) — the reported "
                + "jump to the messages previously sent from the Web client",
            file: file, line: line)

        // The batch belongs above the viewport: seeing any of it (or the
        // separator) without scrolling IS the reported jump.
        assertWebMessagesNotInViewport("after the web-sent batch arrived",
                                       file: file, line: line)
        XCTAssertFalse(
            separatorIsInViewport(),
            "The 'New messages' separator is back inside the viewport (frame "
                + "\(screen.unreadSeparator.frame)) after the web-sent batch "
                + "arrived — the scroll position was re-anchored to the unread "
                + "position, where the Web messages now sit",
            file: file, line: line)

        // Guard against a vacuous pass: the batch must actually be there,
        // just above — scrolling up a little must reveal it.
        revealWebMessagesByScrollingUp(file: file, line: line)
    }

    // MARK: - "New messages" separator placement around the Web-sent run

    /// Cold start whose server sync completed BEFORE the channel was opened:
    /// the Web-sent run already sits in the store between the read history
    /// and the received messages. Opening the channel must place the "New
    /// messages" separator on the boundary of the first RECEIVED message —
    /// the user's own Web-sent messages are not "new" for their author, so
    /// they belong ABOVE the separator as plain history.
    func test_open_withSeededWebRun_separatorSitsAboveFirstReceivedMessage() {
        openConversation(unreadCount: 12, longUnread: true, webSyncSeededCount: 6)
        waitUntilListSettles()
        assertSeparatorSitsAboveFirstReceivedMessage(
            "on open with the Web-sent run already synced")
    }

    /// The reported scenario with NO user interaction: the screen rests at
    /// the "New messages" anchor showing the received messages when the
    /// Web-sent batch lands mid-history. The received messages must keep
    /// their screen position and the separator must hand over to the
    /// received-block boundary — not present the user's own messages as new.
    func test_open_unread_atAnchor_webBatchArrives_receivedMessagesKeepPosition() {
        openConversation(unreadCount: 12, longUnread: true, webSyncButtonCount: 6)
        runNoDragWebSyncArrival()
    }

    /// Same, with the sync's observer-window recalculation following the
    /// insert — the full production shape.
    func test_open_unread_atAnchor_webBatchWithSyncRecalc_receivedMessagesKeepPosition() {
        openConversation(unreadCount: 12, longUnread: true,
                         webSyncButtonCount: 6, webSyncButtonRestart: true)
        runNoDragWebSyncArrival()
    }

    /// Shared body of the two no-interaction arrivals.
    private func runNoDragWebSyncArrival(file: StaticString = #filePath,
                                         line: UInt = #line) {
        XCTAssertTrue(screen.unreadSeparator.waitForExistence(timeout: 10),
                      "The 'New messages' separator should show on open",
                      file: file, line: line)
        XCTAssertTrue(screen.injectWebSyncButton.waitForExistence(timeout: 10),
                      "The floating web-sync injector should be installed",
                      file: file, line: line)
        waitUntilListSettles(file: file, line: line)

        let firstReceived = screen.cell(Convo.unreadTailId(1))
        XCTAssertTrue(firstReceived.waitForExistence(timeout: 10),
                      "The first received message should be on screen at the anchor",
                      file: file, line: line)
        let frameBefore = firstReceived.frame

        tapWebSyncButtonAndVerifyLanded(file: file, line: line)
        wait(seconds: 3)

        XCTAssertTrue(firstReceived.exists,
                      "The first received message (was at \(frameBefore)) is gone "
                          + "from the realized cells after the Web-sent batch — the "
                          + "viewport left the received messages. " + viewportDescription(),
                      file: file, line: line)
        guard firstReceived.exists else { return }
        let drift = firstReceived.frame.midY - frameBefore.midY
        XCTAssertLessThanOrEqual(
            abs(drift), 16,
            "The received message the user was reading moved "
                + String(format: "%.1f", drift) + "pt (from \(frameBefore) to "
                + "\(firstReceived.frame)) when the Web-sent batch arrived — "
                + "the reported 'I see different messages' jump. " + viewportDescription(),
            file: file, line: line)
        assertSeparatorSitsAboveFirstReceivedMessage(
            "after the Web-sent batch landed with no interaction",
            file: file, line: line)
    }

    // MARK: - No-interaction variants: the short push tail, clamped to the bottom

    /// The phone-shaped state of the report: only a couple of received
    /// messages (a push-announced tail too short to fill a screen), so the
    /// open clamps the viewport to the bottom. The Web-sent batch lands after
    /// the open has settled; the newest received message must keep resting
    /// fully visible at the bottom — not yield the screen to the Web block.
    func test_open_twoUnread_webBatchArrivesAfterSettle_staysAtBottom() {
        openConversation(unreadCount: 2, webSyncOnOpenDelayMs: 2000)

        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest received message on open")

        // Outlive the 2s injection delay, then require the bottom to hold.
        wait(seconds: 4)
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest received message after the web-sent batch landed")
        // The separator hands over to the received-block boundary: with the
        // short tail resting at the bottom it legitimately stays on screen,
        // directly above the first received message — never below any
        // Web-sent one.
        assertSeparatorSitsAboveFirstReceivedMessage(
            "after the web-sent batch landed at the bottom")
    }

    /// The same short tail, but the sync page lands DURING the open transition
    /// (150ms — mid push-animation, racing the initial scroll), as it does on
    /// a cold start from a tapped push notification. Wherever the race is won,
    /// the settled result must be the received messages at the bottom.
    func test_open_twoUnread_webBatchArrivesDuringOpen_staysAtBottom() {
        openConversation(unreadCount: 2, webSyncOnOpenDelayMs: 150)

        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest received message (web batch raced the open)")
        wait(seconds: 2)
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest received message once the racing web batch settled")
    }

    /// The racing arrival paired with the observer-window recalculation — the
    /// full production sync shape, landing right as the open transition ends.
    func test_open_twoUnread_webBatchWithSyncRecalcDuringOpen_staysAtBottom() {
        openConversation(unreadCount: 2, webSyncOnOpenDelayMs: 350, webSyncOnOpenRestart: true)

        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest received message (web batch + recalc raced the open)")
        wait(seconds: 2)
        assertRestsAtBottom(newest: screen.cell(Convo.unreadTailId(2)),
                            "the newest received message once the racing web batch + recalc settled")
        assertSeparatorSitsAboveFirstReceivedMessage(
            "after the racing web batch + recalc settled at the bottom")
    }

    // MARK: - Gestures

    /// A short, slow, momentum-free drag toward the newer messages (finger
    /// moves up ~28% of the list height, then holds before lifting so no
    /// deceleration follows). Coordinates stay clear of the floating injector
    /// buttons on the left edge and of the cell centers' long-press zones.
    private func dragListSlightly() {
        let from = screen.collectionView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.85, dy: 0.62))
        let to = screen.collectionView.coordinate(
            withNormalizedOffset: CGVector(dx: 0.85, dy: 0.34))
        from.press(forDuration: 0.05,
                   thenDragTo: to,
                   withVelocity: 300,
                   thenHoldForDuration: 0.3)
    }

    /// Whether the web-sync injector button reports a committed insert (the
    /// app-side harness stamps the injected count into its accessibility value
    /// once the database write succeeds).
    private func webSyncButtonReportsLanded() -> Bool {
        guard let value = screen.injectWebSyncButton.value as? String,
              let count = Int(value)
        else { return false }
        return count > 0
    }

    /// Taps the web-sync injector and verifies the insert actually committed.
    /// The insert can be dropped (it races the mark-displayed write) or the
    /// tap can miss — either would make no-change assertions pass vacuously.
    /// The button stamps the injected count into its accessibility value only
    /// after the write commits; re-tap until confirmed (the insert is
    /// idempotent — fixed ids — so a re-tap never duplicates messages).
    private func tapWebSyncButtonAndVerifyLanded(file: StaticString, line: UInt) {
        screen.injectWebSyncButton.tap()
        var taps = 1
        while !waitFor(timeout: 2, { self.webSyncButtonReportsLanded() }), taps < 3 {
            taps += 1
            screen.injectWebSyncButton.tap()
        }
        XCTAssertTrue(webSyncButtonReportsLanded(),
                      "The web-sync insert should commit (injector button never "
                          + "reported a landed batch after \(taps) taps)",
                      file: file, line: line)
    }

    /// Asserts the "New messages" separator sits on the boundary of the first
    /// received (incoming unread) message: visible, with the first received
    /// message starting directly below it, and any visible Web-sent message
    /// lying strictly ABOVE it — own messages must never render as "new".
    private func assertSeparatorSitsAboveFirstReceivedMessage(
        _ context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let separator = screen.unreadSeparator
        XCTAssertTrue(separator.waitForExistence(timeout: 10),
                      "\(context): the 'New messages' separator should exist",
                      file: file, line: line)
        XCTAssertTrue(separatorIsInViewport(),
                      "\(context): the separator should be inside the viewport "
                          + "(frame \(separator.frame)). " + viewportDescription(),
                      file: file, line: line)
        let firstReceived = screen.cell(Convo.unreadTailId(1))
        XCTAssertTrue(firstReceived.waitForExistence(timeout: 10),
                      "\(context): the first received message should be realized",
                      file: file, line: line)
        let gap = firstReceived.frame.minY - separator.frame.maxY
        XCTAssertTrue(gap >= -2 && gap <= 40,
                      "\(context): the first received message should start directly "
                          + "below the 'New messages' separator, but the gap is "
                          + String(format: "%.1f", gap) + "pt (separator "
                          + "\(separator.frame), first received \(firstReceived.frame)) "
                          + "— the separator is not anchored on the received block",
                      file: file, line: line)
        let webBelowSeparator = webMessageFrames().filter {
            $0.intersects(viewportFrame) && $0.minY > separator.frame.maxY - 2
        }
        XCTAssertTrue(webBelowSeparator.isEmpty,
                      "\(context): Web-sent messages render BELOW the 'New messages' "
                          + "separator (\(webBelowSeparator)) — the user's own "
                          + "messages are being presented as new/unread",
                      file: file, line: line)
    }

    /// Scrolls up (finger drags down) until a web-sent message becomes visible,
    /// proving the batch really landed just above the viewport. Bounded so a
    /// missing batch fails fast instead of scrolling forever.
    private func revealWebMessagesByScrollingUp(file: StaticString, line: UInt) {
        for _ in 1...6 {
            if webMessageIsInViewport() { return }
            let from = screen.collectionView.coordinate(
                withNormalizedOffset: CGVector(dx: 0.85, dy: 0.35))
            let to = screen.collectionView.coordinate(
                withNormalizedOffset: CGVector(dx: 0.85, dy: 0.75))
            from.press(forDuration: 0.05,
                       thenDragTo: to,
                       withVelocity: 600,
                       thenHoldForDuration: 0.2)
            _ = waitFor(timeout: 1) { self.webMessageIsInViewport() }
        }
        XCTAssertTrue(
            webMessageIsInViewport(),
            "Scrolling up after the injection should reveal the Web-sent block "
                + "right above the viewport — it never appeared, even though the "
                + "injector confirmed the insert committed. "
                + viewportDescription(),
            file: file, line: line)
    }

    // MARK: - Viewport queries

    /// The window frame — the visible viewport.
    private var viewportFrame: CGRect { app.windows.firstMatch.frame }

    /// The realized message cell whose vertical center is nearest the
    /// viewport's center — the message the user is actually reading.
    private func midViewportMessageCell() -> (identifier: String, frame: CGRect)? {
        let midY = viewportFrame.midY
        return messageCellFrames()
            .filter { $0.frame.intersects(viewportFrame) }
            .min(by: { abs($0.frame.midY - midY) < abs($1.frame.midY - midY) })
    }

    /// Frames of every realized web-sent message body (one atomic snapshot).
    private func webMessageFrames() -> [CGRect] {
        guard let root = try? app.snapshot() else { return [] }
        var frames: [CGRect] = []
        func walk(_ node: XCUIElementSnapshot) {
            if node.elementType == .staticText,
               node.identifier == ChannelScreen.AID.body,
               node.label.hasPrefix("Sent from Web") {
                frames.append(node.frame)
            }
            node.children.forEach(walk)
        }
        walk(root)
        return frames
    }

    /// Whether any web-sent message cell is currently inside the viewport.
    /// Realized-but-offscreen cells still `exist`, so frames must intersect.
    private func webMessageIsInViewport() -> Bool {
        webMessageFrames().contains { $0.intersects(viewportFrame) }
    }

    private func assertWebMessagesNotInViewport(_ context: String,
                                                file: StaticString,
                                                line: UInt) {
        XCTAssertFalse(
            webMessageIsInViewport(),
            "\(context): a 'Sent from Web' message is inside the viewport — the "
                + "scroll position moved onto the batch that arrived above",
            file: file, line: line)
    }

    /// Where the viewport actually is — the visible message cells, and whether
    /// the separator or the Web-sent block is on screen. Appended to failure
    /// messages so a jump names its landing place.
    private func viewportDescription() -> String {
        let visible = messageCellFrames()
            .filter { $0.frame.intersects(viewportFrame) }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map { "\($0.identifier.replacingOccurrences(of: ChannelScreen.AID.cellRoot + ".", with: ""))@y\(Int($0.frame.minY))" }
        return "Viewport now shows: [\(visible.joined(separator: ", "))]"
            + (separatorIsInViewport() ? " + the 'New messages' separator" : "")
            + (webMessageIsInViewport() ? " + the Web-sent block" : "")
    }

    /// Whether the "New messages" separator is currently inside the visible
    /// window (frames must intersect; existence alone is not enough).
    private func separatorIsInViewport() -> Bool {
        let separator = screen.unreadSeparator
        guard separator.exists else { return false }
        return separator.frame.intersects(viewportFrame)
    }

    /// One atomic accessibility snapshot of every message cell's
    /// (identifier, frame) — immune to cells churning between element binding
    /// and attribute access (mirrors `ChannelOpenPositionUITests`).
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

    /// Waits until two consecutive snapshots of the realized cells agree —
    /// the open/settle (or post-drag) animations are done.
    private func waitUntilListSettles(file: StaticString = #filePath,
                                      line: UInt = #line) {
        var previous = messageCellFrames().map { "\($0.identifier)@\($0.frame)" }
        let settled = waitFor(timeout: 8) {
            let current = self.messageCellFrames().map { "\($0.identifier)@\($0.frame)" }
            defer { previous = current }
            return !current.isEmpty && current == previous
        }
        XCTAssertTrue(settled, "The message list should stop moving",
                      file: file, line: line)
    }

    // MARK: - Bottom-rest assertion (mirrors ChannelOpenPositionUITests)

    /// Asserts the list rests at the bottom: `cell` (the newest message) must
    /// sit FULLY above the composer — a half-hidden bubble still reports
    /// `isHittable`, which is exactly the failure to catch.
    private func assertRestsAtBottom(newest cell: XCUIElement,
                                     _ name: String,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) {
        XCTAssertTrue(cell.waitForExistence(timeout: 10),
                      "\(name) should exist", file: file, line: line)
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
                + "pt below the composer top (cell \(cell.frame), composer top "
                + "\(composerTop)) — the viewport left the received messages",
            file: file, line: line)
    }

    // MARK: - Waiting

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

    /// Unconditional wait (for windows with no positive completion signal).
    private func wait(seconds: TimeInterval) {
        _ = waitFor(timeout: seconds) { false }
    }
}
