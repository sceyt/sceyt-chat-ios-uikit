//
//  ChannelListScrollSuppressionTests.swift
//  SceytChatUIKitTests
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//
//  The channel list turns table scrolling off for the duration of an in-cell
//  swipe. Leaving it off is the one severe failure mode of doing that — a list
//  that will not scroll — so these tests pin the ways it must recover.
//

import XCTest
@testable import SceytChatUIKit

final class ChannelListScrollSuppressionTests: XCTestCase {

    private typealias Cell = ChannelListViewController.ChannelCell

    private var sut: ChannelListViewController!

    override func setUp() {
        super.setUp()
        sut = ChannelListViewController()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    private func makeCell() -> Cell {
        Cell(style: .default, reuseIdentifier: "test")
    }

    // MARK: - The happy path still suppresses

    func test_begin_suppressesScrolling() {
        sut.swipeDidBegin(on: makeCell())
        XCTAssertFalse(sut.tableView.isScrollEnabled)
    }

    func test_beginThenEnd_restoresScrolling() {
        let cell = makeCell()
        sut.swipeDidBegin(on: cell)
        sut.swipeDidEnd(on: cell)
        XCTAssertTrue(sut.tableView.isScrollEnabled)
    }

    // MARK: - A second swipe must not poison the saved value

    /// Two rows dragged at once: nothing stops both pans beginning, and the
    /// second capture used to record the already-suppressed `false` as the
    /// value to put back — latching the list unscrollable for good.
    func test_twoConcurrentSwipes_stillRestoreScrolling() {
        let first = makeCell()
        let second = makeCell()

        sut.swipeDidBegin(on: first)
        sut.swipeDidBegin(on: second)
        XCTAssertFalse(sut.tableView.isScrollEnabled)

        sut.swipeDidEnd(on: first)
        XCTAssertTrue(sut.tableView.isScrollEnabled, "the second begin must not have overwritten the saved value")

        sut.swipeDidEnd(on: second)
        XCTAssertTrue(sut.tableView.isScrollEnabled)
    }

    // MARK: - A lost end event must not strand the suppression

    /// The generic leak: `.began` was delivered, the pan is over, and the
    /// `.settled` that would have restored scrolling never arrived — a cell
    /// recycled or deallocated mid-pan, or a callback severed in between.
    /// A layout pass reconciles against the gesture and recovers.
    func test_lostEndEvent_isRecoveredByALayoutPass() {
        let cell = makeCell()
        sut.swipeDidBegin(on: cell)
        XCTAssertFalse(sut.tableView.isScrollEnabled)

        // No `swipeDidEnd`. The pan is not running (a fresh recognizer is
        // `.possible`), so the suppression is no longer justified.
        sut.viewDidLayoutSubviews()
        XCTAssertTrue(sut.tableView.isScrollEnabled)
    }

    func test_lostEndEvent_isRecoveredOnReturningToTheList() {
        sut.swipeDidBegin(on: makeCell())
        sut.viewWillAppear(false)
        XCTAssertTrue(sut.tableView.isScrollEnabled)
    }

    func test_lostEndEvent_isRecoveredOnLeavingTheList() {
        sut.swipeDidBegin(on: makeCell())
        sut.viewWillDisappear(false)
        XCTAssertTrue(sut.tableView.isScrollEnabled)
    }

    /// The swiping cell being gone is the strongest form of the leak: there is
    /// no gesture left to ask, and nothing will ever report an end.
    func test_deallocatedSwipingCell_doesNotStrandTheSuppression() {
        autoreleasepool {
            let cell = makeCell()
            sut.swipeDidBegin(on: cell)
        }
        XCTAssertFalse(sut.tableView.isScrollEnabled)

        sut.viewDidLayoutSubviews()
        XCTAssertTrue(sut.tableView.isScrollEnabled)
    }

    // MARK: - Reconciliation must not fight the host app

    /// A host app that disabled scrolling for its own reasons gets that back,
    /// not a blanket `true` — the saved value is restored, as designed.
    func test_scrollingDisabledBeforeTheSwipe_isRestoredAsDisabled() {
        sut.tableView.isScrollEnabled = false
        let cell = makeCell()
        sut.swipeDidBegin(on: cell)
        sut.swipeDidEnd(on: cell)
        XCTAssertFalse(sut.tableView.isScrollEnabled)
    }

    /// Reconciling when no swipe ever started must leave the table alone.
    func test_reconcilingWithNoSwipeInFlight_leavesScrollingUntouched() {
        sut.tableView.isScrollEnabled = false
        sut.viewDidLayoutSubviews()
        XCTAssertFalse(sut.tableView.isScrollEnabled, "no suppression is active, so nothing to restore")
    }
}
