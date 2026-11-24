//
//  ChannelListBatchUpdateTests.swift
//  SceytChatUIKitTests
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//
//  The imperative channel list applies observer index paths with
//  `performBatchUpdates`. UIKit raises NSInternalInconsistencyException (an
//  uncatchable crash in Swift) when those paths do not take the table's rows to
//  the data source's row count — Crashlytics e5ae779b…, reported on v1.6.16.
//  These tests pin that a mismatched batch reloads instead of crashing.
//

import XCTest
@testable import SceytChatUIKit

/// A view model whose row count the test sets directly, with no database.
private final class StubChannelListViewModel: ChannelListViewModel {
    var rowCount = 0

    override func startDatabaseObserver() {}
    override func loadChannels() {}
    override func numberOfChannel(at section: Int) -> Int {
        section == 0 ? rowCount : 0
    }
}

final class ChannelListBatchUpdateTests: XCTestCase {

    private typealias Paths = ChannelListViewModel.Paths

    private var window: UIWindow!
    private var sut: ChannelListViewController!
    private var viewModel: StubChannelListViewModel!

    override func setUp() {
        super.setUp()
        viewModel = StubChannelListViewModel()
        sut = ChannelListViewController()
        sut.dataSourceMode = .imperative
        sut.channelListViewModel = viewModel
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        sut = nil
        viewModel = nil
        super.tearDown()
    }

    /// Puts the list on screen with `rows` rows, so `updateTableView` takes the
    /// `performBatchUpdates` branch (window, visible cells, did appear).
    private func showList(rows: Int) {
        viewModel.rowCount = rows
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = sut
        window.makeKeyAndVisible()
        sut.viewDidAppear(false)
        sut.tableView.reloadData()
        sut.tableView.layoutIfNeeded()
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), rows)
        XCTAssertFalse(sut.tableView.visibleCells.isEmpty, "precondition: batch branch needs visible cells")
    }

    private func ip(_ row: Int) -> IndexPath { IndexPath(row: row, section: 0) }

    // MARK: - The reported crash

    /// The crash shape: the view model already holds a newer list (two rows
    /// added) but the paths describe only one insert. Used to throw
    /// "invalid number of rows in section 0".
    func test_insertPathsBehindTheViewModel_reloadsInsteadOfCrashing() {
        showList(rows: 3)
        viewModel.rowCount = 5

        sut.updateTableView(paths: Paths(inserts: [ip(0)]))
        sut.tableView.layoutIfNeeded()

        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 5)
    }

    func test_deletePathsBehindTheViewModel_reloadsInsteadOfCrashing() {
        showList(rows: 5)
        viewModel.rowCount = 3

        sut.updateTableView(paths: Paths(deletes: [ip(4)]))
        sut.tableView.layoutIfNeeded()

        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 3)
    }

    // MARK: - Consistent batches still animate as a batch

    func test_consistentInsert_isAppliedAsABatch() {
        showList(rows: 3)
        viewModel.rowCount = 4
        let paths = Paths(inserts: [ip(0)])

        XCTAssertTrue(sut.canApplyBatchUpdates(paths: paths))
        sut.updateTableView(paths: paths)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 4)
    }

    func test_consistentMoveAndUpdate_isAppliedAsABatch() {
        showList(rows: 4)
        let paths = Paths(updates: [ip(1)], moves: [(from: ip(3), to: ip(0))])

        XCTAssertTrue(sut.canApplyBatchUpdates(paths: paths))
        sut.updateTableView(paths: paths)
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 4)
    }

    // MARK: - Every other shape UIKit rejects

    func test_rejects_countMismatch() {
        showList(rows: 3)
        viewModel.rowCount = 5
        XCTAssertFalse(sut.canApplyBatchUpdates(paths: Paths(inserts: [ip(0)])))
    }

    func test_rejects_updateOutOfRange() {
        showList(rows: 3)
        XCTAssertFalse(sut.canApplyBatchUpdates(paths: Paths(updates: [ip(3)])))
    }

    func test_rejects_deleteOutOfRange() {
        showList(rows: 3)
        viewModel.rowCount = 2
        XCTAssertFalse(sut.canApplyBatchUpdates(paths: Paths(deletes: [ip(7)])))
    }

    func test_rejects_insertOutOfRange() {
        showList(rows: 3)
        viewModel.rowCount = 4
        XCTAssertFalse(sut.canApplyBatchUpdates(paths: Paths(inserts: [ip(9)])))
    }

    func test_rejects_moveTargetOutOfRange() {
        showList(rows: 3)
        XCTAssertFalse(sut.canApplyBatchUpdates(paths: Paths(moves: [(from: ip(0), to: ip(3))])))
    }

    /// "attempt to delete and reload the same index path".
    func test_rejects_deleteAndReloadOfTheSameRow() {
        showList(rows: 3)
        viewModel.rowCount = 2
        XCTAssertFalse(sut.canApplyBatchUpdates(paths: Paths(updates: [ip(1)], deletes: [ip(1)])))
    }

    func test_rejects_sectionChanges() {
        showList(rows: 3)
        XCTAssertFalse(sut.canApplyBatchUpdates(paths: Paths(sectionInserts: [1])))
    }

    func test_mismatchedUpdate_reloadsInsteadOfCrashing() {
        showList(rows: 3)
        sut.updateTableView(paths: Paths(updates: [ip(5)]))
        sut.tableView.layoutIfNeeded()
        XCTAssertEqual(sut.tableView.numberOfRows(inSection: 0), 3)
    }
}
