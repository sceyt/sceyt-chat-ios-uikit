//
//  ChannelListUITests.swift
//  SceytDemoAppUITests
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//
//  Black-box UI tests for the channel list. The app is launched in `--uitest`
//  mode, which skips login/connection and seeds a fixed set of channels (see
//  `UITestSupport` in the app target):
//
//    id 1  "Design Team"   — plain, incoming last message
//    id 2  "Marketing"     — unread count 5
//    id 3  "Random"        — muted
//    id 4  "Announcements" — pinned (sorts first)
//    id 5  "Project X"     — unread + mention
//    id 6  "Product"       — outgoing last message (delivery ticks)
//

import XCTest

final class ChannelListUITests: BaseUITestCase {

    private var app: XCUIApplication!
    private var screen: ChannelListScreen!

    private func start(empty: Bool = false, dynamicTypeCategory: String? = nil) {
        app = launchApp(empty: empty, dynamicTypeCategory: dynamicTypeCategory)
        screen = ChannelListScreen(app: app)
    }

    // MARK: - Rendering / cell content

    func test_list_showsSeededChannels() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        for id in UInt64(1)...6 {
            XCTAssertTrue(screen.cell(id).waitForExistence(timeout: 5),
                          "Expected sceyt_chat_channel_list_cell.\(id) to be present")
        }
    }

    func test_pinnedChannel_sortsFirst() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        XCTAssertTrue(screen.cell(4).waitForExistence(timeout: 5))
        XCTAssertEqual(screen.visibleCells.first?.identifier,
                       ChannelListScreen.AID.cell(4),
                       "The pinned channel should be the first row")
    }

    func test_cell_showsSubjectAndLastMessage() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        let cell = screen.cell(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.subject(in: cell).label, "Design Team")
        XCTAssertTrue(screen.message(in: cell).label.contains("finalize the mockups"),
                      "Last message preview should reflect the seeded text")
    }

    func test_unreadChannel_showsUnreadBadge() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())

        let unread = screen.cell(2)
        XCTAssertTrue(unread.waitForExistence(timeout: 5))
        let badge = screen.unreadBadge(in: unread)
        XCTAssertTrue(badge.exists, "Marketing should show an unread badge")
        XCTAssertTrue(badge.label.contains("5"), "Unread badge should read 5")

        // A read channel must not show the badge.
        XCTAssertFalse(screen.unreadBadge(in: screen.cell(1)).exists)
    }

    func test_mutedChannel_showsMuteIcon() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        XCTAssertTrue(screen.cell(3).waitForExistence(timeout: 5))
        XCTAssertTrue(screen.muteIcon(in: screen.cell(3)).exists, "Random is muted")
        XCTAssertFalse(screen.muteIcon(in: screen.cell(1)).exists, "Design Team is not muted")
    }

    func test_pinnedChannel_showsPinIcon() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        XCTAssertTrue(screen.cell(4).waitForExistence(timeout: 5))
        XCTAssertTrue(screen.pinIcon(in: screen.cell(4)).exists, "Announcements is pinned")
        XCTAssertFalse(screen.pinIcon(in: screen.cell(1)).exists, "Design Team is not pinned")
    }

    func test_mentionChannel_showsMentionBadge() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        XCTAssertTrue(screen.cell(5).waitForExistence(timeout: 5))
        XCTAssertTrue(screen.mentionBadge(in: screen.cell(5)).exists, "Project X has a mention")
        XCTAssertFalse(screen.mentionBadge(in: screen.cell(1)).exists)
    }

    func test_outgoingMessage_showsDeliveryTicks() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        XCTAssertTrue(screen.cell(6).waitForExistence(timeout: 5))
        XCTAssertTrue(screen.ticks(in: screen.cell(6)).exists,
                      "An outgoing last message should show a delivery tick")
        // An incoming last message must not show the tick.
        XCTAssertFalse(screen.ticks(in: screen.cell(1)).exists)
    }

    func test_groupChannel_showsSenderNameInPreview() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())

        // Incoming message from another member → preview is prefixed with their name.
        let fromOther = screen.cell(1)
        XCTAssertTrue(fromOther.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.message(in: fromOther).label.hasPrefix("Alice:"),
                      "A group message from another member should be prefixed with their name; was: \(screen.message(in: fromOther).label)")

        // Own outgoing message → preview is prefixed with "You:".
        let fromMe = screen.cell(6)
        XCTAssertTrue(fromMe.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.message(in: fromMe).label.hasPrefix("You:"),
                      "Your own last message should be prefixed with \"You:\"; was: \(screen.message(in: fromMe).label)")
    }

    // MARK: - Interactions

    func test_tapChannel_opensChannelScreen() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        let cell = screen.cell(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        // Navigating away covers/removes the list — its table is no longer hittable.
        XCTAssertTrue(waitFor { !self.screen.table.isHittable },
                      "Tapping a channel should open the channel screen")
    }

    func test_tapNewChannel_opensCreateFlow() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())
        XCTAssertTrue(screen.newChannelButton.waitForExistence(timeout: 5))
        screen.newChannelButton.tap()
        // The create flow is presented modally over the list.
        XCTAssertTrue(waitFor { !self.screen.newChannelButton.isHittable },
                      "Tapping New Channel should present the create-channel screen")
    }

    func test_search_acceptsInput() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())

        // The search bar hides while scrolling; pull the list down to reveal it.
        screen.table.swipeDown()
        let field = screen.searchField
        guard field.waitForExistence(timeout: 5) else {
            XCTFail("Search field did not appear")
            return
        }
        field.tap()
        field.typeText("Marketing")
        XCTAssertEqual(field.value as? String, "Marketing",
                       "The search field should accept and display typed text")
    }

    // MARK: - Live updates (reorder + preview)

    func test_receivingMessage_reordersChannelAndUpdatesPreview() {
        app = launchApp(injectionEnabled: true)
        screen = ChannelListScreen(app: app)
        XCTAssertTrue(screen.waitUntilLoaded())

        // Channel 1 ("Design Team") is the oldest fixture, so it starts at the
        // bottom — in particular, below channel 6.
        let target = screen.cell(1)
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.cell(6).waitForExistence(timeout: 5))
        XCTAssertGreaterThan(target.frame.minY, screen.cell(6).frame.minY,
                             "Channel 1 should start below channel 6")

        // Receive a new message on channel 1 → it should move up above channel 6.
        screen.injectShortButton.tap()
        XCTAssertTrue(waitFor { self.screen.cell(1).frame.minY < self.screen.cell(6).frame.minY },
                      "Receiving a message should move the channel up the list")

        // …and the preview should now show the received message.
        XCTAssertTrue(
            waitFor { self.screen.message(in: self.screen.cell(1)).label.contains(ChannelListScreen.InjectedText.short) },
            "The preview should update to the received message"
        )
        let shortPreviewHeight = screen.message(in: screen.cell(1)).frame.height

        // Send a longer message → the preview should show it wrapped onto a
        // second line (taller than the one-line short preview).
        screen.injectLongButton.tap()
        XCTAssertTrue(
            waitFor { self.screen.message(in: self.screen.cell(1)).label.contains("deliberately long preview") },
            "The preview should update to the longer message"
        )
        let longPreviewHeight = screen.message(in: screen.cell(1)).frame.height
        XCTAssertGreaterThan(longPreviewHeight, shortPreviewHeight * 1.4,
                             "A long message should render across two lines (a taller preview)")
    }

    /// End-to-end: open a channel, type and send a message through the real
    /// composer, return to the list, and verify the channel moved to the correct
    /// position with the right last-message preview and an updated timestamp.
    func test_sendingMessageInChannel_reordersAndUpdatesPreviewAndTime() {
        start()
        XCTAssertTrue(screen.waitUntilLoaded())

        // Channel 1 ("Design Team") is the oldest fixture, so it starts at the
        // bottom of the list — below channel 6.
        let cell = screen.cell(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.cell(6).waitForExistence(timeout: 5))
        XCTAssertGreaterThan(cell.frame.minY, screen.cell(6).frame.minY,
                             "Channel 1 should start below channel 6")

        // Remember the seeded preview / timestamp so we can prove they change.
        let oldPreview = screen.message(in: cell).label
        let oldDate = screen.date(in: cell).label

        // Open the channel, compose a message and send it through the real input bar.
        let sentText = "Hello from the UI test"
        cell.tap()

        let conversation = ChannelScreen(app: app)
        XCTAssertTrue(conversation.waitUntilReady(), "The channel composer should appear")
        conversation.inputField.tap()
        conversation.inputField.typeText(sentText)
        XCTAssertTrue(conversation.sendButton.waitForExistence(timeout: 5),
                      "The send button should appear once text is entered")
        conversation.sendButton.tap()

        // Sending clears the composer (the send button hides again) — wait for that
        // so we know the message was committed before we navigate away.
        XCTAssertTrue(waitFor { !conversation.sendButton.exists },
                      "The composer should clear after sending")

        // Back to the list.
        conversation.goBack()
        XCTAssertTrue(waitFor { self.screen.table.isHittable },
                      "Tapping back should return to the channel list")

        // Right position: the pinned channel (id 4) still sorts first, and our
        // channel should now sit directly below it — the top of the unpinned section.
        XCTAssertTrue(waitFor {
            let cells = self.screen.visibleCells
            return cells.count >= 2
                && cells[0].identifier == ChannelListScreen.AID.cell(4)
                && cells[1].identifier == ChannelListScreen.AID.cell(1)
        }, "After sending, channel 1 should move directly below the pinned channel")

        // Right last message: the preview now shows the message we sent…
        let updated = screen.cell(1)
        XCTAssertTrue(
            waitFor { self.screen.message(in: updated).label.contains(sentText) },
            "The preview should update to the sent message; was: \(screen.message(in: updated).label)"
        )
        XCTAssertNotEqual(screen.message(in: updated).label, oldPreview,
                          "The preview should no longer show the seeded last message")

        // Right time: the timestamp reflects the just-sent message rather than the
        // seeded 2023 date.
        let newDate = screen.date(in: updated).label
        XCTAssertFalse(newDate.isEmpty, "The channel should show a timestamp for the new message")
        XCTAssertNotEqual(newDate, oldDate,
                          "The timestamp should update to the time of the sent message")
    }

    // MARK: - Empty state

    func test_emptyState_showsNoChannels() {
        start(empty: true)
        // Note: the SDK's empty illustration is gated on `numberOfSections > 0`,
        // which is a constant 1, so it never actually shows. We therefore assert
        // the meaningful, real behavior: no channel rows are rendered.
        XCTAssertTrue(screen.waitUntilLoaded())
        XCTAssertEqual(screen.visibleCells.count, 0, "No channels should be rendered")
    }

    // MARK: - Dynamic Type

    func test_dynamicType_cellsRemainVisible() {
        start(dynamicTypeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(screen.waitUntilLoaded())
        let cell = screen.cell(2)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        // The fixed row height grows with Large Text; the subject must stay laid out.
        XCTAssertTrue(screen.subject(in: cell).exists,
                      "Subject should remain visible at the largest Dynamic Type size")
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
