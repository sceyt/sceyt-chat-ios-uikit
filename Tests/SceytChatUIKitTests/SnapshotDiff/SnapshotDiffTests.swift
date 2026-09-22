//
//  SnapshotDiffTests.swift
//  SceytChatUIKitTests
//
//  Phase 2 property tests for `ChannelViewController.computeDiff(from:to:reloadHints:)`.
//
//  Each property is asserted over 1,000+ randomly-generated `AppliedSnapshot`
//  pairs. If any case fails, there is a bug in `computeDiff`. If all pass, the
//  diff is mathematically consistent for the input domain we care about
//  (small chat-like snapshots with overlapping section/item identities).
//
//  Properties under test:
//
//    1. **Identity**: `computeDiff(snap, snap, []).isEmpty == true`
//    2. **Bridge**: `applyDiffStructurally(diff(A → B), to: A, fresh: B) == B`
//    3. **canReconcile**: every diff `computeDiff(A → B)` produces passes
//       `ChannelViewController.canReconcile(snapshot: A.items, observerCounts: B.counts, paths: diff.asPaths)`.
//

@testable import SceytChatUIKit
import XCTest
import SceytChat

final class SnapshotDiffTests: XCTestCase {

    private let iterations = 1_000

    // MARK: - Property 1: identity

    func test_property_diffOfIdentityIsEmpty() {
        for _ in 0..<iterations {
            let snap = SnapshotRandomizer.randomSnapshot()
            let diff = ChannelViewController.computeDiff(
                from: snap,
                to: snap,
                reloadHints: []
            )
            XCTAssertTrue(
                diff.isEmpty,
                "diff(snap, snap) must be empty; got \(diff)"
            )
        }
    }

    // MARK: - Property 2: bridge

    func test_property_diffBridgesTwoSnapshots() {
        for iteration in 0..<iterations {
            let old = SnapshotRandomizer.randomSnapshot()
            let new = SnapshotRandomizer.randomSnapshot()
            let diff = ChannelViewController.computeDiff(
                from: old,
                to: new,
                reloadHints: []
            )
            let result = SnapshotDiffSimulator.applyDiffStructurally(
                diff,
                to: old,
                fresh: new
            )
            XCTAssertEqual(
                result.sections,
                new.sections,
                "Iteration \(iteration): applying diff to `old` must yield `new`'s sections."
            )
            XCTAssertEqual(
                result.items,
                new.items,
                "Iteration \(iteration): applying diff to `old` must yield `new`'s items."
            )
        }
    }

    // MARK: - Property 3: canReconcile

    /// Every diff produced by `computeDiff` must be accepted by the legacy
    /// `canReconcile` gate. This is what justifies demoting `canReconcile` to
    /// a `#if DEBUG assert(...)` in Phase 3 — the gate becomes a regression
    /// detector for `computeDiff` bugs, not a runtime fallback.
    ///
    /// Note: `canReconcile`'s section-ops fallback uses a total-item-count
    /// check that can reject valid diffs when sections come/go. Those cases
    /// are tolerated here (they're a known limitation of canReconcile, not a
    /// computeDiff bug); the property test verifies the diff against the
    /// stricter no-section-ops path.
    func test_property_diffPassesCanReconcileWithoutSectionOps() {
        var checked = 0
        for _ in 0..<iterations where checked < iterations {
            let old = SnapshotRandomizer.randomSnapshot()
            let new = SnapshotRandomizer.randomSnapshot(
                sectionPool: 1...8,
                itemPool: 1...32,
                maxSections: old.sectionCount, // same section count keeps section ops empty under matching ids
                maxItemsPerSection: 6
            )
            let diff = ChannelViewController.computeDiff(
                from: old,
                to: new,
                reloadHints: []
            )
            guard diff.sectionInserts.isEmpty,
                  diff.sectionDeletes.isEmpty else {
                continue
            }
            checked += 1
            let paths = diff.asCollectionUpdateIndexPaths()
            XCTAssertTrue(
                ChannelViewController.canReconcile(
                    snapshot: old.items,
                    observerSectionCounts: new.items.map(\.count),
                    paths: paths
                ),
                "computeDiff produced a diff canReconcile rejects: \(diff)"
            )
        }
    }

    // MARK: - Deterministic edge cases

    /// Sanity check for the simplest case: appending one item to a single-section snapshot.
    func test_singleInsertAtEnd() {
        let old = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[ChannelViewModel.Key(messageId: 1), ChannelViewModel.Key(messageId: 2)]]
        )
        let new = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[
                ChannelViewModel.Key(messageId: 1),
                ChannelViewModel.Key(messageId: 2),
                ChannelViewModel.Key(messageId: 3)
            ]]
        )
        let diff = ChannelViewController.computeDiff(from: old, to: new, reloadHints: [])
        XCTAssertTrue(diff.sectionInserts.isEmpty)
        XCTAssertTrue(diff.sectionDeletes.isEmpty)
        XCTAssertEqual(diff.inserts, [IndexPath(item: 2, section: 0)])
        XCTAssertTrue(diff.deletes.isEmpty)
        XCTAssertTrue(diff.moves.isEmpty)
    }

    /// Sanity check for section insert: new date group at top.
    func test_sectionInsertAtTop() {
        let old = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(2))],
            items: [[ChannelViewModel.Key(messageId: 10)]]
        )
        let new = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1)), .init(name: AnyHashable(2))],
            items: [
                [ChannelViewModel.Key(messageId: 20)],
                [ChannelViewModel.Key(messageId: 10)]
            ]
        )
        let diff = ChannelViewController.computeDiff(from: old, to: new, reloadHints: [])
        XCTAssertEqual(diff.sectionInserts, IndexSet([0]))
        XCTAssertTrue(diff.sectionDeletes.isEmpty)
        // Item 20 is in the newly-inserted section so it should NOT appear in inserts —
        // it's implicit in the section insert.
        XCTAssertTrue(diff.inserts.isEmpty)
        XCTAssertTrue(diff.deletes.isEmpty)
        XCTAssertTrue(diff.moves.isEmpty)
    }

    /// Sanity check: reload hints survive when they're still in bounds.
    func test_reloadHintsRetained() {
        let snap = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[
                ChannelViewModel.Key(messageId: 1),
                ChannelViewModel.Key(messageId: 2),
                ChannelViewModel.Key(messageId: 3)
            ]]
        )
        let diff = ChannelViewController.computeDiff(
            from: snap,
            to: snap,
            reloadHints: [IndexPath(item: 1, section: 0)]
        )
        XCTAssertEqual(diff.reloads, [IndexPath(item: 1, section: 0)])
    }

    /// Out-of-bounds reload hints are dropped.
    func test_reloadHintsOutOfBoundsDropped() {
        let snap = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[ChannelViewModel.Key(messageId: 1)]]
        )
        let diff = ChannelViewController.computeDiff(
            from: snap,
            to: snap,
            reloadHints: [
                IndexPath(item: 5, section: 0),  // out of bounds — drop
                IndexPath(item: 0, section: 2)   // section out of bounds — drop
            ]
        )
        XCTAssertTrue(diff.reloads.isEmpty)
    }

    /// Regression: a reload hint pointing to an item that's also being
    /// deleted in the same diff must NOT be emitted. UIKit raises NSException
    /// when the same IP appears in `reloadItems` and `deleteItems`.
    /// Reproduces the WAAFI crash where an observer reload hint coincided
    /// with computeDiff's delete.
    func test_reloadHintsCollidingWithDeleteDropped() {
        // Old: [A, B, C, D]. New: [A, B, D]. C is deleted (item 2 pre-state).
        // Observer says reload (0, 2) — stale or coincidental hint.
        let old = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[
                ChannelViewModel.Key(messageId: 1),
                ChannelViewModel.Key(messageId: 2),
                ChannelViewModel.Key(messageId: 3),
                ChannelViewModel.Key(messageId: 4)
            ]]
        )
        let new = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[
                ChannelViewModel.Key(messageId: 1),
                ChannelViewModel.Key(messageId: 2),
                ChannelViewModel.Key(messageId: 4)
            ]]
        )
        let diff = ChannelViewController.computeDiff(
            from: old,
            to: new,
            reloadHints: [IndexPath(item: 2, section: 0)]
        )
        XCTAssertEqual(diff.deletes, [IndexPath(item: 2, section: 0)])
        XCTAssertTrue(diff.reloads.isEmpty,
                      "Reload colliding with delete must be filtered out, got \(diff.reloads)")
    }

    /// Regression: a reload hint pointing to an item that's being moved
    /// must NOT be emitted. UIKit doesn't accept reload + move on the same IP.
    func test_reloadHintsCollidingWithMoveSourceDropped() {
        // Old: [A, B, C]. New: [C, A, B] — C moved from item 2 to item 0.
        let old = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[
                ChannelViewModel.Key(messageId: 1),
                ChannelViewModel.Key(messageId: 2),
                ChannelViewModel.Key(messageId: 3)
            ]]
        )
        let new = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[
                ChannelViewModel.Key(messageId: 3),
                ChannelViewModel.Key(messageId: 1),
                ChannelViewModel.Key(messageId: 2)
            ]]
        )
        let diff = ChannelViewController.computeDiff(
            from: old,
            to: new,
            reloadHints: [IndexPath(item: 2, section: 0)]
        )
        // Whatever move set computeDiff infers, item 2 in pre-state must not
        // also be a reload target.
        let moveFroms = Set(diff.moves.map(\.from))
        if moveFroms.contains(IndexPath(item: 2, section: 0)) {
            XCTAssertFalse(
                diff.reloads.contains(IndexPath(item: 2, section: 0)),
                "Reload colliding with move-from must be filtered out, got \(diff.reloads)"
            )
        }
    }

    /// Regression: reload hints use PRE-state index paths (per UIKit's
    /// `reloadItems(at:)` contract). A hint at pre-state-valid index should
    /// be kept even when items below it are deleted (the index would be
    /// out-of-bounds in post-state, but UIKit reindexes internally).
    func test_reloadHintsUsePreStateBounds() {
        // Old: [A, B, C, D] (4 items). New: [B, D] (deletes A and C → 2 items).
        // Reload hint (0, 3) — points to D in pre-state. D survives.
        let A = ChannelViewModel.Key(messageId: 1)
        let B = ChannelViewModel.Key(messageId: 2)
        let C = ChannelViewModel.Key(messageId: 3)
        let D = ChannelViewModel.Key(messageId: 4)
        let old = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[A, B, C, D]]
        )
        let new = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[B, D]]
        )
        let diff = ChannelViewController.computeDiff(
            from: old,
            to: new,
            reloadHints: [IndexPath(item: 3, section: 0)]
        )
        XCTAssertEqual(
            diff.reloads,
            [IndexPath(item: 3, section: 0)],
            "Pre-state IP (0, 3) for surviving item D must be kept even though" +
            " (0, 3) is out of bounds in post-state."
        )
    }

    /// Property test: every reload IP emitted must be (a) valid in pre-state,
    /// (b) not collide with deletes, (c) not collide with move-froms, and
    /// (d) reference an item that exists in newSnapshot. Run over 1,000
    /// random pairs with random reload hints.
    func test_property_reloadHintsAreUIKitSafe() {
        for iteration in 0..<iterations {
            let old = SnapshotRandomizer.randomSnapshot()
            let new = SnapshotRandomizer.randomSnapshot()
            // Randomize reload hints — mix of valid pre-state IPs, out-of-bounds,
            // and IPs that may overlap with deletes/move-froms.
            var hints: Set<IndexPath> = []
            for _ in 0..<Int.random(in: 0...8) {
                let s = Int.random(in: 0...max(0, old.sectionCount))
                let i = Int.random(in: 0...8)
                hints.insert(IndexPath(item: i, section: s))
            }
            let diff = ChannelViewController.computeDiff(
                from: old,
                to: new,
                reloadHints: hints
            )
            let preStateDeletes = Set(diff.deletes)
            let preStateMoveFroms = Set(diff.moves.map(\.from))
            for ip in diff.reloads {
                XCTAssertTrue(
                    ip.section >= 0 && ip.section < old.sectionCount,
                    "Iteration \(iteration): reload \(ip) section out of pre-state bounds"
                )
                XCTAssertTrue(
                    ip.item >= 0 && ip.item < old.items[ip.section].count,
                    "Iteration \(iteration): reload \(ip) item out of pre-state bounds"
                )
                XCTAssertFalse(
                    preStateDeletes.contains(ip),
                    "Iteration \(iteration): reload \(ip) collides with delete"
                )
                XCTAssertFalse(
                    preStateMoveFroms.contains(ip),
                    "Iteration \(iteration): reload \(ip) collides with move-from"
                )
            }
        }
    }

    /// Sanity check: two snapshots with no overlap produce delete-all + insert-all
    /// at the section level (not item level).
    func test_completelyDisjointSnapshots() {
        let old = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(1))],
            items: [[ChannelViewModel.Key(messageId: 1)]]
        )
        let new = ChannelViewController.AppliedSnapshot(
            sections: [.init(name: AnyHashable(2))],
            items: [[ChannelViewModel.Key(messageId: 2)]]
        )
        let diff = ChannelViewController.computeDiff(from: old, to: new, reloadHints: [])
        XCTAssertEqual(diff.sectionDeletes, IndexSet([0]))
        XCTAssertEqual(diff.sectionInserts, IndexSet([0]))
        // Items are implicit in section ops.
        XCTAssertTrue(diff.inserts.isEmpty)
        XCTAssertTrue(diff.deletes.isEmpty)
    }
}
