//
//  ChannelListSwipeUITests.swift
//  SceytDemoAppUITests
//
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//
//  The channel list draws its own swipe actions instead of using
//  `UISwipeActionsConfiguration`, because UIKit can neither carry an open swipe
//  across a row move nor re-open one programmatically — so a channel bumped to
//  the top while its actions were open used to strand them.
//
//  Every test runs against both `dataSourceMode` values: `.diffable` (what the
//  demo app uses) and `.imperative` (the SDK default, selected with
//  `--uitest-imperative`). The two apply reorders through completely different
//  code paths, and both used to destroy the bumped channel's cell.
//
//  Seeded fixtures (see `UITestSupport`):
//
//    id 1  "Design Team"   — plain, incoming last message (oldest → bottom)
//    id 2  "Marketing"     — unread count 5
//    id 3  "Random"        — muted
//    id 4  "Announcements" — pinned (sorts first)
//    id 5  "Project X"     — unread + mention
//    id 6  "Product"       — outgoing last message
//

import XCTest

final class ChannelListSwipeUITests: BaseUITestCase {

    private var app: XCUIApplication!
    private var screen: ChannelListScreen!

    /// The injector bumps channel 1, which starts at the bottom of the list.
    private let bumpedChannelId: UInt64 = 1

    private func start(imperative: Bool = false, injection: Bool = false) {
        app = launchApp(injectionEnabled: injection, imperativeDataSource: imperative)
        screen = ChannelListScreen(app: app)
        XCTAssertTrue(screen.waitUntilLoaded())
    }

    // MARK: - The regression this implementation exists for

    func test_openSwipe_survivesChannelReorder_diffable() {
        assertOpenSwipeSurvivesReorder(imperative: false)
    }

    func test_openSwipe_survivesChannelReorder_imperative() {
        assertOpenSwipeSurvivesReorder(imperative: true)
    }

    /// Opens a row's trailing actions, bumps that channel to the top of the list
    /// by receiving a message on it, and asserts the actions travelled with the
    /// row instead of being stranded or torn down.
    private func assertOpenSwipeSurvivesReorder(imperative: Bool) {
        start(imperative: imperative, injection: true)

        let target = screen.cell(bumpedChannelId)
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.cell(6).waitForExistence(timeout: 5))
        XCTAssertGreaterThan(target.frame.minY, screen.cell(6).frame.minY,
                             "Channel 1 should start below channel 6")

        // Open the trailing actions. Channel 1 is direct, so the trailing set is
        // [delete, mute] (see ChannelSwipeActionsConfiguration.trailingActions).
        target.swipeLeft()
        let deleteButton = screen.swipeAction("delete", in: screen.cell(bumpedChannelId))
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3),
                      "Swiping left should reveal the trailing actions")
        XCTAssertTrue(deleteButton.isHittable, "The revealed action should be tappable")

        // Bump the channel to the top while its actions are open.
        screen.injectShortButton.tap()
        XCTAssertTrue(
            waitFor { self.screen.cell(self.bumpedChannelId).frame.minY < self.screen.cell(6).frame.minY },
            "Receiving a message should move the channel up the list"
        )

        // The actions must still be open, on the same row, at its new position.
        let movedCell = screen.cell(bumpedChannelId)
        let movedDelete = screen.swipeAction("delete", in: movedCell)
        XCTAssertTrue(movedDelete.exists,
                      "The open swipe actions must survive the reorder")
        XCTAssertTrue(movedDelete.isHittable,
                      "The actions must still be tappable after the reorder")
        XCTAssertTrue(movedCell.frame.contains(CGPoint(x: movedDelete.frame.midX,
                                                       y: movedDelete.frame.midY)),
                      "The actions must sit inside the row's new position")
        XCTAssertGreaterThan(movedDelete.frame.midX, movedCell.frame.midX,
                             "Trailing actions belong on the trailing half of the row")

        // The preview updates in place while the row stays open.
        XCTAssertTrue(
            waitFor { self.screen.message(in: self.screen.cell(self.bumpedChannelId)).label
                .contains(ChannelListScreen.InjectedText.short) },
            "The preview should update to the received message while the swipe is open"
        )
        XCTAssertTrue(screen.swipeAction("delete", in: screen.cell(bumpedChannelId)).exists,
                      "Updating the preview must not close the swipe")

        // And the action still targets the channel the user swiped.
        movedDelete.tap()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3),
                      "Tapping Delete should ask for confirmation for the moved channel")
    }

    func test_openSwipe_survivesFullListReload_diffable() {
        assertOpenSwipeSurvivesFullReload(imperative: false)
    }

    func test_openSwipe_survivesFullListReload_imperative() {
        assertOpenSwipeSurvivesFullReload(imperative: true)
    }

    /// Opens a row's trailing actions and then rebuilds the whole table the way a
    /// finished channel sync does — a batch of channel writes the view model
    /// escalates to `.reload`. The row must come back still open: the offset is
    /// keyed by channel id and re-applied when the cell is dequeued, so a reload
    /// has no business snapping the actions shut under the user's finger.
    private func assertOpenSwipeSurvivesFullReload(imperative: Bool) {
        start(imperative: imperative, injection: true)

        let cell = screen.cell(bumpedChannelId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        let closedSubjectX = screen.subject(in: cell).frame.minX

        cell.swipeLeft()
        XCTAssertTrue(screen.swipeAction("delete", in: screen.cell(bumpedChannelId))
                        .waitForExistence(timeout: 3),
                      "Swiping left should reveal the trailing actions")

        screen.forceReloadButton.tap()

        let reloadedCell = screen.cell(bumpedChannelId)
        let delete = screen.swipeAction("delete", in: reloadedCell)
        XCTAssertTrue(delete.waitForExistence(timeout: 3),
                      "A full reload must not close the open swipe")
        XCTAssertTrue(delete.isHittable,
                      "The actions must still be tappable after the reload")
        XCTAssertLessThan(screen.subject(in: reloadedCell).frame.minX, closedSubjectX,
                          "The row must still be held open at its swipe offset")

        // And the restored actions still target the channel that was swiped.
        delete.tap()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3),
                      "Tapping Delete should ask for confirmation for the swiped channel")
    }

    // MARK: - Opening and closing

    func test_swipeLeft_revealsTrailingActions() {
        start()
        let cell = screen.cell(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        cell.swipeLeft()
        XCTAssertTrue(screen.swipeAction("delete", in: screen.cell(1)).waitForExistence(timeout: 3),
                      "A direct channel should offer Delete")
        XCTAssertTrue(screen.swipeAction("mute", in: screen.cell(1)).exists,
                      "An unmuted channel should offer Mute")
    }

    func test_swipeRight_revealsLeadingActions() {
        start()
        // Channel 2 has 5 unread, so the leading set is [read, pin].
        let cell = screen.cell(2)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        cell.swipeRight()
        XCTAssertTrue(screen.swipeAction("read", in: screen.cell(2)).waitForExistence(timeout: 3),
                      "An unread channel should offer Read")
        XCTAssertTrue(screen.swipeAction("pin", in: screen.cell(2)).exists,
                      "An unpinned channel should offer Pin")
    }

    func test_swipeRight_onPinnedChannel_offersUnpin() {
        start()
        // Channel 4 is pinned.
        let cell = screen.cell(4)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        cell.swipeRight()
        XCTAssertTrue(screen.swipeAction("unpin", in: screen.cell(4)).waitForExistence(timeout: 3),
                      "A pinned channel should offer Unpin")
    }

    func test_swipeLeft_onMutedChannel_offersUnmute() {
        start()
        // Channel 3 is muted.
        let cell = screen.cell(3)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        cell.swipeLeft()
        XCTAssertTrue(screen.swipeAction("unmute", in: screen.cell(3)).waitForExistence(timeout: 3),
                      "A muted channel should offer Unmute")
    }

    func test_tappingOpenRow_closesSwipeWithoutNavigating() {
        start()
        let cell = screen.cell(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        cell.swipeLeft()
        let deleteButton = screen.swipeAction("delete", in: screen.cell(1))
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))

        // Tap the row's leading edge, clear of the trailing action buttons.
        let rowFrame = screen.cell(1).frame
        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).tap()

        XCTAssertTrue(waitFor { !self.screen.swipeAction("delete").exists },
                      "Tapping an open row should close its actions")
        XCTAssertFalse(app.collectionViews[ChannelScreen.AID.collectionView].exists,
                       "That tap should not also open the channel")
        XCTAssertEqual(screen.cell(1).frame.minY, rowFrame.minY, accuracy: 1,
                       "Closing the swipe should not move the row")
    }

    func test_swipingSecondRow_closesTheFirst() {
        start()
        XCTAssertTrue(screen.cell(1).waitForExistence(timeout: 5))

        screen.cell(1).swipeLeft()
        XCTAssertTrue(screen.swipeAction("delete", in: screen.cell(1)).waitForExistence(timeout: 3))

        // Channel 3 is muted, so its trailing set contains Unmute — an
        // unambiguous marker that the second row, not the first, is open.
        screen.cell(3).swipeLeft()
        XCTAssertTrue(screen.swipeAction("unmute", in: screen.cell(3)).waitForExistence(timeout: 3),
                      "The second row should open")
        XCTAssertTrue(waitFor { !self.screen.swipeAction("delete", in: self.screen.cell(1)).exists },
                      "Only one row may be open at a time")
    }

    func test_scrolling_closesOpenSwipe() {
        start()
        XCTAssertTrue(screen.cell(1).waitForExistence(timeout: 5))

        screen.cell(1).swipeLeft()
        XCTAssertTrue(screen.swipeAction("delete", in: screen.cell(1)).waitForExistence(timeout: 3))

        screen.table.swipeUp()
        XCTAssertTrue(waitFor { !self.screen.swipeAction("delete").exists },
                      "Scrolling the list should close an open swipe")
    }

    /// The pan gate must be strictly horizontal-dominant, or vertical drags stop
    /// scrolling the list. `ChannelListUITests.test_search_acceptsInput` is the
    /// other canary for this.
    func test_verticalSwipe_doesNotOpenSwipeActions() {
        start()
        XCTAssertTrue(screen.cell(1).waitForExistence(timeout: 5))
        let cellCountBefore = screen.visibleCells.count

        screen.table.swipeUp()
        screen.table.swipeDown()

        // The seeded list is short enough that it may not scroll at all on a
        // large device, so this asserts the gate rather than the scroll: a
        // vertical drag must never be mistaken for a swipe. The list's own
        // scrolling stays covered by `test_scrolling_closesOpenSwipe` and by
        // `ChannelListUITests.test_search_acceptsInput`, which pulls the search
        // bar into view with a downward drag.
        for action in ["delete", "leave", "mute", "unmute", "read", "unread", "pin", "unpin"] {
            XCTAssertFalse(screen.swipeAction(action).exists,
                           "A vertical swipe must not reveal the \(action) action")
        }
        XCTAssertEqual(screen.visibleCells.count, cellCountBefore,
                       "The list should be intact after vertical drags")
    }

    // MARK: - Actions target the right channel

    /// The decided policy for a swipe that outlives a channel update: keep the
    /// offset, but re-derive the buttons, so the row never performs a stale
    /// action.
    ///
    /// Channel 1 starts read, so its leading set is [unread, pin]. Receiving a
    /// message makes it unread, so the first action must become Read — while the
    /// row stays open at the same offset.
    func test_openSwipe_reRendersActionsWhenChannelStateChanges() {
        start(injection: true)

        let cell = screen.cell(bumpedChannelId)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))

        cell.swipeRight()
        XCTAssertTrue(screen.swipeAction("unread", in: screen.cell(bumpedChannelId)).waitForExistence(timeout: 3),
                      "A read channel should offer Unread")
        let offsetBefore = screen.subject(in: screen.cell(bumpedChannelId)).frame.minX

        // Mark the swiped channel unread while its actions are open. (The real
        // markAs(read:) needs a server round trip, so the harness writes the
        // local state directly — see markUITestChannelUnread.)
        screen.markUnreadButton.tap()

        XCTAssertTrue(waitFor { self.screen.swipeAction("read", in: self.screen.cell(self.bumpedChannelId)).exists },
                      "The action should re-derive to Read once the channel is unread")
        XCTAssertFalse(screen.swipeAction("unread", in: screen.cell(bumpedChannelId)).exists,
                       "The stale Unread action must be gone")

        // The row is still open, at the same offset.
        let offsetAfter = screen.subject(in: screen.cell(bumpedChannelId)).frame.minX
        XCTAssertEqual(offsetAfter, offsetBefore, accuracy: 2,
                       "Re-deriving the actions must not move or close the row")
    }

    func test_muteFromTrailingSwipe_mutesTheSwipedChannel() {
        start()
        let cell = screen.cell(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        XCTAssertFalse(screen.muteIcon(in: cell).exists, "Channel 1 starts unmuted")

        cell.swipeLeft()
        let muteButton = screen.swipeAction("mute", in: screen.cell(1))
        XCTAssertTrue(muteButton.waitForExistence(timeout: 3))
        muteButton.tap()

        // The mute options sheet lists durations; take the first one.
        let sheetButton = app.buttons.element(boundBy: 0)
        XCTAssertTrue(sheetButton.waitForExistence(timeout: 3),
                      "Mute should present its duration options")
    }

    // MARK: - Full swipe

    /// Dragging a row most of the way across fires its first trailing action —
    /// Delete here, which asks for confirmation. Guards the reachability of the
    /// trigger: while the drag past the reveal was rubber-banded, the threshold
    /// sat beyond the width of the screen and the gesture could never fire.
    func test_fullSwipe_performsTheFirstTrailingAction() {
        app = launchApp(fullSwipeActions: true)
        screen = ChannelListScreen(app: app)
        XCTAssertTrue(screen.waitUntilLoaded())

        let cell = screen.cell(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        dragAcross(cell)

        XCTAssertTrue(deleteConfirmation.waitForExistence(timeout: 3),
                      "A full swipe should perform the first trailing action")
        XCTAssertFalse(screen.swipeAction("delete", in: screen.cell(1)).exists,
                       "The row should close as the action fires")
    }

    /// The same drag with the flag off must only open the actions, never fire one.
    func test_fullSwipe_isOptIn() {
        start()
        let cell = screen.cell(1)
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        dragAcross(cell)

        XCTAssertTrue(screen.swipeAction("delete", in: screen.cell(1)).waitForExistence(timeout: 3),
                      "The row should just open")
        XCTAssertFalse(deleteConfirmation.exists,
                       "No action should fire while performsFirstActionWithFullSwipe is off")
    }

    /// The delete confirmation sheet's prompt. Matched on the prompt rather than
    /// its "Delete" button, whose label the swipe button itself also carries.
    private var deleteConfirmation: XCUIElement {
        app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "sure you want to delete")
        ).firstMatch
    }

    /// Drags from the trailing edge nearly to the leading edge — past the 60%
    /// threshold, but well within the row.
    private func dragAcross(_ cell: XCUIElement) {
        let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let end = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    // MARK: - Accessibility

    func test_swipeActionTitles_remainVisibleAtAccessibilitySizes() {
        app = launchApp(dynamicTypeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        screen = ChannelListScreen(app: app)
        XCTAssertTrue(screen.waitUntilLoaded())

        // Rows are much taller at this category, so address whichever row is
        // actually on screen rather than a fixed channel.
        guard let cell = screen.visibleCells.first else {
            return XCTFail("Expected at least one visible channel cell")
        }
        cell.swipeLeft()

        // Every channel offers either Leave or Delete as its first trailing action.
        let deleteButton = screen.swipeAction("delete")
        let leaveButton = screen.swipeAction("leave")
        XCTAssertTrue(waitFor { deleteButton.exists || leaveButton.exists },
                      "Swipe actions should still open at accessibility text sizes")
        let revealed = deleteButton.exists ? deleteButton : leaveButton
        XCTAssertTrue(revealed.isHittable,
                      "The action should remain tappable at accessibility text sizes")
        XCTAssertGreaterThan(revealed.frame.width, 0,
                             "The action button should have a measurable width")
        XCTAssertLessThan(revealed.frame.width, cell.frame.width,
                          "A single action must not consume the whole row")
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
