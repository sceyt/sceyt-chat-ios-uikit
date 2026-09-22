//
//  CanReconcileTests.swift
//  SceytChatUIKitTests
//
//  Tier 1 unit tests for `ChannelViewController.canReconcile(snapshot:observerSectionCounts:paths:)`.
//
//  Each test constructs a synthetic `appliedSnapshot`, an observer-state count
//  array, and a `CollectionUpdateIndexPaths`, then asserts whether the gate
//  accepts or rejects the diff.
//
//  Tests are tagged in their doc comment with one of:
//
//    EXPECTED: PASS         — should pass against the current code AND after hardening.
//                             Documents an existing protection (regression coverage).
//
//    EXPECTED: FAIL (now)   — fails against the current count-only `canReconcile`.
//                             The malformed input slips through the gate today and
//                             would crash UIKit's `performBatchUpdates`. This test
//                             documents a crash class to close. Goes GREEN once the
//                             hardening plan (CAN_RECONCILE_HARDENING_PLAN.md) lands.
//

@testable import SceytChatUIKit
import XCTest
import SceytChat

final class CanReconcileTests: XCTestCase {

    // Aliases to keep test bodies readable.
    private typealias Key = ChannelViewModel.Key

    private func canReconcile(
        snapshot: [[Key]],
        observerSectionCounts: [Int],
        paths: CollectionUpdateIndexPaths
    ) -> Bool {
        ChannelViewController.canReconcile(
            snapshot: snapshot,
            observerSectionCounts: observerSectionCounts,
            paths: paths
        )
    }

    // MARK: - Risk #1 — out-of-range individual indices

    /// EXPECTED: FAIL (now). Count math balances (3 + 1 = 4) so the gate
    /// returns true, but item 15 is beyond the post-state section's 4 items.
    /// UIKit will crash with "attempt to insert item at index 15 in section
    /// containing 4 items."
    func test_rejects_insertItemBeyondPostStateCount() {
        let snap: [[Key]] = [[.fake(1), .fake(2), .fake(3)]]
        let counts = [4]
        let paths = CollectionUpdateIndexPaths(
            inserts: [IndexPath(item: 15, section: 0)]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Insert at item 15 with only 4 post-state items must be rejected.")
    }

    /// EXPECTED: FAIL (now). Count math (2 − 1 = 1) balances; delete at item
    /// 5 doesn't reference any item in the 2-item pre-state. UIKit will crash
    /// with "attempt to delete item at index 5 in section containing 2 items."
    func test_rejects_deleteFromNonexistentItem() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [1]
        let paths = CollectionUpdateIndexPaths(
            deletes: [IndexPath(item: 5, section: 0)]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Delete at item 5 when section has only 2 items must be rejected.")
    }

    /// EXPECTED: FAIL (now). Count math balances; item index −1 is meaningless.
    /// UIKit crashes on negative item indices.
    func test_rejects_negativeItemIndex() {
        let snap: [[Key]] = [[.fake(1)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            inserts: [IndexPath(item: -1, section: 0)]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Insert at negative item index must be rejected.")
    }

    /// EXPECTED: FAIL (now). Section count matches (1 == 1) and per-section
    /// count math for section 0 balances (paths.inserts targets section 5, so
    /// section 0's delta is 0). The malformed insert in section 5 — which
    /// doesn't exist — is invisible to the count-only gate. UIKit crashes
    /// with "attempt to insert item in nonexistent section."
    func test_rejects_insertInNonexistentSection() {
        let snap: [[Key]] = [[.fake(1)]]
        let counts = [1]
        let paths = CollectionUpdateIndexPaths(
            inserts: [IndexPath(item: 0, section: 5)]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Insert in nonexistent section 5 must be rejected.")
    }

    /// EXPECTED: PASS (post-hardening). Reload at item 5 when section has
    /// only 2 items. Reload uses pre-state coordinates — Pass 3 bounds check.
    ///
    /// Note: UIKit on iOS 26 does NOT raise NSException for an out-of-range
    /// reload (it's silently absorbed) — see the note in
    /// `MalformedPathFixtures.swift`. So this test is defensive rather than
    /// strictly crash-preventing: an out-of-range reload signals a stale
    /// path, and the gate rejects to force a rebuild instead of applying
    /// a path whose OTHER operations may yet be malformed.
    func test_rejects_reloadAtNonexistentItem() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            reloads: [IndexPath(item: 5, section: 0)]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Reload at item 5 when section has only 2 items must be rejected.")
    }

    /// EXPECTED: PASS (post-hardening). Move from item 5 in a 2-item section.
    /// `move.from` uses pre-state coordinates — Pass 3 bounds check. UIKit
    /// raises "attempt to move nonexistent item."
    func test_rejects_moveFromNonexistentItem() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            moves: [(from: IndexPath(item: 5, section: 0),
                     to:   IndexPath(item: 0, section: 0))]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Move from item 5 when section has only 2 items must be rejected.")
    }

    /// EXPECTED: PASS (post-hardening). Move to item 99 when post-state
    /// section has only 2 items. `move.to` uses post-state coordinates —
    /// Pass 4 bounds check. UIKit raises an invalid index path error.
    func test_rejects_moveToBeyondPostStateCount() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            moves: [(from: IndexPath(item: 0, section: 0),
                     to:   IndexPath(item: 99, section: 0))]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Move to item 99 when post-state section has only 2 items must be rejected.")
    }

    // MARK: - Risk #2 — reload overlapping deletes / move-froms

    /// EXPECTED: FAIL (now). Count math balances (2 − 1 = 1). UIKit crashes
    /// with "attempt to reload and delete the same index path."
    func test_rejects_reloadAndDeleteSameIndex() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [1]
        let paths = CollectionUpdateIndexPaths(
            reloads: [IndexPath(item: 0, section: 0)],
            deletes: [IndexPath(item: 0, section: 0)]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Reload and delete on the same index path must be rejected.")
    }

    /// EXPECTED: FAIL (now). Count math balances (2 items, intra-section move
    /// doesn't change counts). UIKit treats move-from as a deletion internally,
    /// so reloading the same index path is undefined / crashes.
    func test_rejects_reloadAndMoveFromSameIndex() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            reloads: [IndexPath(item: 0, section: 0)],
            moves: [(from: IndexPath(item: 0, section: 0),
                     to:   IndexPath(item: 1, section: 0))]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Reload at a move-source index path must be rejected.")
    }

    // MARK: - Risk #3 — item ops on sections being inserted/deleted
    //
    // No tests here. Tier 2 integration testing (PerformBatchUpdatesIntegration-
    // Tests) showed that modern iOS UIKit does not raise NSException for the
    // scenarios originally flagged as Risk #3. The hardening plan was revised
    // to drop the Risk #3 validation pass — see CAN_RECONCILE_HARDENING_PLAN.md.

    // MARK: - Risk #4 — move / insert / delete overlap

    /// EXPECTED: FAIL (now). Move uniqueness check passes (one move source,
    /// one move destination, no duplicates). Per-section math balances
    /// (3 − 1 = 2). UIKit crashes: cannot delete an item that is also a
    /// move source.
    func test_rejects_deleteAtMoveFromIndex() {
        let snap: [[Key]] = [[.fake(1), .fake(2), .fake(3)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            deletes: [IndexPath(item: 0, section: 0)],
            moves: [(from: IndexPath(item: 0, section: 0),
                     to:   IndexPath(item: 1, section: 0))]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Delete colliding with move-from index path must be rejected.")
    }

    /// EXPECTED: FAIL (now). Move uniqueness OK; per-section math balances
    /// (2 + 1 = 3). UIKit crashes: cannot insert at a location that is also
    /// a move destination.
    func test_rejects_insertAtMoveToIndex() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [3]
        let paths = CollectionUpdateIndexPaths(
            inserts: [IndexPath(item: 1, section: 0)],
            moves: [(from: IndexPath(item: 0, section: 0),
                     to:   IndexPath(item: 1, section: 0))]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Insert colliding with move-to index path must be rejected.")
    }

    /// EXPECTED: PASS. Existing move-uniqueness check catches this:
    /// two moves with the same `from` violate UIKit's distinct-source rule.
    func test_rejects_duplicateMoveSources() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            moves: [
                (from: IndexPath(item: 0, section: 0), to: IndexPath(item: 1, section: 0)),
                (from: IndexPath(item: 0, section: 0), to: IndexPath(item: 0, section: 0))
            ]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Duplicate move sources must be rejected.")
    }

    /// EXPECTED: PASS. Existing move-uniqueness check catches duplicate `to`.
    func test_rejects_duplicateMoveDestinations() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            moves: [
                (from: IndexPath(item: 0, section: 0), to: IndexPath(item: 1, section: 0)),
                (from: IndexPath(item: 1, section: 0), to: IndexPath(item: 1, section: 0))
            ]
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Duplicate move destinations must be rejected.")
    }

    // MARK: - Existing checks — regression coverage

    /// EXPECTED: PASS. Snapshot claims 1 section; observer reports 2. No
    /// section ops describe the transition, so reconcile must reject.
    func test_rejects_sectionCountMismatch() {
        let snap: [[Key]] = [[.fake(1)]]
        let counts = [1, 1]
        let paths = CollectionUpdateIndexPaths()
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Section count mismatch with no section ops must be rejected.")
    }

    /// EXPECTED: PASS. Sections match (1 == 1), but observer claims 10 items
    /// in section 0 while snapshot has 2 and paths describe no changes.
    func test_rejects_perSectionCountMismatch() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [10]
        let paths = CollectionUpdateIndexPaths()
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Per-section count mismatch must be rejected.")
    }

    /// EXPECTED: PASS (post-hardening). Pass 7's section-ops branch uses a
    /// total-count comparison. Snapshot has 1 item, paths adds 1, but the
    /// observer claims the post-state has 7 items total across two sections.
    /// 1 + 1 − 0 ≠ 7, so reconcile must reject. This is the only test
    /// exercising the `else` branch of Pass 7 in the negative direction.
    func test_rejects_totalCountMismatchWithSectionOps() {
        let snap: [[Key]] = [[.fake(1)]]
        let counts = [2, 5]
        let paths = CollectionUpdateIndexPaths(
            inserts: [IndexPath(item: 0, section: 1)],
            sectionInserts: IndexSet([1])
        )
        XCTAssertFalse(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths),
                       "Total-count mismatch with section ops present must be rejected.")
    }

    // MARK: - Positive cases — valid diffs must be accepted

    /// EXPECTED: PASS. Empty diff and matching counts.
    func test_accepts_emptyDiff() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths()
        XCTAssertTrue(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths))
    }

    /// EXPECTED: PASS. Simple append at end of section.
    func test_accepts_simpleInsertAtEnd() {
        let snap: [[Key]] = [[.fake(1), .fake(2)]]
        let counts = [3]
        let paths = CollectionUpdateIndexPaths(
            inserts: [IndexPath(item: 2, section: 0)]
        )
        XCTAssertTrue(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths))
    }

    /// EXPECTED: PASS. Single delete.
    func test_accepts_deleteOnly() {
        let snap: [[Key]] = [[.fake(1), .fake(2), .fake(3)]]
        let counts = [2]
        let paths = CollectionUpdateIndexPaths(
            deletes: [IndexPath(item: 1, section: 0)]
        )
        XCTAssertTrue(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths))
    }

    /// EXPECTED: PASS. Intra-section move doesn't change counts.
    func test_accepts_intraSectionMove() {
        let snap: [[Key]] = [[.fake(1), .fake(2), .fake(3)]]
        let counts = [3]
        let paths = CollectionUpdateIndexPaths(
            moves: [(from: IndexPath(item: 0, section: 0),
                     to:   IndexPath(item: 2, section: 0))]
        )
        XCTAssertTrue(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths))
    }

    /// EXPECTED: PASS. Cross-section move shifts one item between sections.
    /// This exercises Pass 7's `mIn`/`mOut` accumulator (which intra-section
    /// moves never reach). Section 0 loses one item; section 1 gains one.
    /// Pre: [[K1, K2], [K3]]  →  Post: [[K2], [K1, K3]] (K1 moves to (0, 1)).
    func test_accepts_crossSectionMove() {
        let snap: [[Key]] = [[.fake(1), .fake(2)], [.fake(3)]]
        let counts = [1, 2]
        let paths = CollectionUpdateIndexPaths(
            moves: [(from: IndexPath(item: 0, section: 0),
                     to:   IndexPath(item: 0, section: 1))]
        )
        XCTAssertTrue(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths))
    }

    /// EXPECTED: PASS. Reloads on valid pre-state indices, no overlaps.
    func test_accepts_reloadsAtValidIndices() {
        let snap: [[Key]] = [[.fake(1), .fake(2), .fake(3)]]
        let counts = [3]
        let paths = CollectionUpdateIndexPaths(
            reloads: [IndexPath(item: 0, section: 0), IndexPath(item: 2, section: 0)]
        )
        XCTAssertTrue(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths))
    }

    /// EXPECTED: PASS. Section insert that adds an empty new section at the
    /// front, plus an item insert into it. Total math balances: 1 + 1 = 2.
    func test_accepts_sectionInsertWithItem() {
        let snap: [[Key]] = [[.fake(1)]]
        let counts = [1, 1]
        let paths = CollectionUpdateIndexPaths(
            inserts: [IndexPath(item: 0, section: 0)],
            sectionInserts: IndexSet([0])
        )
        XCTAssertTrue(canReconcile(snapshot: snap, observerSectionCounts: counts, paths: paths))
    }
}
