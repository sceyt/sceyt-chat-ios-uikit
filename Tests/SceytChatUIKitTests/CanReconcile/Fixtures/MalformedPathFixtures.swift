//
//  MalformedPathFixtures.swift
//  SceytChatUIKitTests
//
//  Catalog of `CollectionUpdateIndexPaths` payloads that are crash-inducing
//  when applied via `UICollectionView.performBatchUpdates`. Used by the
//  integration test suite to assert TWO properties simultaneously:
//
//    A) `canReconcile` rejects the fixture pre-flight.
//    B) Bypassing the gate and applying the fixture to a real UICollectionView
//       raises NSException — proving the fixture is a real UIKit crash, not
//       a theoretical one our static analysis invented.
//
//  Each fixture mirrors one of the negative test cases in CanReconcileTests.
//

@testable import SceytChatUIKit
import Foundation

struct MalformedPathFixture {
    let name: String
    let risk: String                                // for failure diagnostics
    let snapshot: [[ChannelViewModel.Key]]
    let observerCounts: [Int]
    let paths: CollectionUpdateIndexPaths
}

enum MalformedPathFixtures {
    static let all: [MalformedPathFixture] = [

        // MARK: Risk #1 — out-of-range individual indices

        .init(
            name: "insertItemBeyondPostStateCount",
            risk: "#1 out-of-bounds",
            snapshot: [[.fake(1), .fake(2), .fake(3)]],
            observerCounts: [4],
            paths: CollectionUpdateIndexPaths(
                inserts: [IndexPath(item: 15, section: 0)]
            )
        ),

        .init(
            name: "deleteFromNonexistentItem",
            risk: "#1 out-of-bounds",
            snapshot: [[.fake(1), .fake(2)]],
            observerCounts: [1],
            paths: CollectionUpdateIndexPaths(
                deletes: [IndexPath(item: 5, section: 0)]
            )
        ),

        .init(
            name: "negativeItemIndex",
            risk: "#1 out-of-bounds",
            snapshot: [[.fake(1)]],
            observerCounts: [2],
            paths: CollectionUpdateIndexPaths(
                inserts: [IndexPath(item: -1, section: 0)]
            )
        ),

        .init(
            name: "insertInNonexistentSection",
            risk: "#1 out-of-bounds",
            snapshot: [[.fake(1)]],
            observerCounts: [1],
            paths: CollectionUpdateIndexPaths(
                inserts: [IndexPath(item: 0, section: 5)]
            )
        ),

        // Note: a `reloadAtNonexistentItem` fixture was tested here and found
        // NOT to crash UIKit on iOS 26 — UIKit silently absorbs out-of-range
        // reloads. `canReconcile` still rejects this defensively (see the
        // corresponding Tier 1 test `test_rejects_reloadAtNonexistentItem`),
        // because an out-of-range reload signals a stale path whose other
        // operations may genuinely crash. The gate stays strict; the Tier 2
        // catalog tracks only confirmed UIKit-crash classes.

        .init(
            name: "moveFromNonexistentItem",
            risk: "#1 out-of-bounds (pre-state move source)",
            snapshot: [[.fake(1), .fake(2)]],
            observerCounts: [2],
            paths: CollectionUpdateIndexPaths(
                moves: [(from: IndexPath(item: 5, section: 0),
                         to:   IndexPath(item: 0, section: 0))]
            )
        ),

        .init(
            name: "moveToBeyondPostStateCount",
            risk: "#1 out-of-bounds (post-state move destination)",
            snapshot: [[.fake(1), .fake(2)]],
            observerCounts: [2],
            paths: CollectionUpdateIndexPaths(
                moves: [(from: IndexPath(item: 0, section: 0),
                         to:   IndexPath(item: 99, section: 0))]
            )
        ),

        // MARK: Risk #2 — reload overlapping deletes / move-froms

        .init(
            name: "reloadAndDeleteSameIndex",
            risk: "#2 reload overlap",
            snapshot: [[.fake(1), .fake(2)]],
            observerCounts: [1],
            paths: CollectionUpdateIndexPaths(
                reloads: [IndexPath(item: 0, section: 0)],
                deletes: [IndexPath(item: 0, section: 0)]
            )
        ),

        .init(
            name: "reloadAndMoveFromSameIndex",
            risk: "#2 reload overlap",
            snapshot: [[.fake(1), .fake(2)]],
            observerCounts: [2],
            paths: CollectionUpdateIndexPaths(
                reloads: [IndexPath(item: 0, section: 0)],
                moves: [(from: IndexPath(item: 0, section: 0),
                         to:   IndexPath(item: 1, section: 0))]
            )
        ),

        // MARK: Risk #3 — item ops on sections being inserted/deleted
        //
        // No fixtures here. Empirical testing (Tier 2 integration suite) showed
        // that modern iOS UIKit does NOT throw NSException for the scenarios
        // originally flagged as Risk #3:
        //
        //   - Deleting an item inside a section that is also being deleted in
        //     the same batch: UIKit treats the item-level delete as redundant
        //     and accepts the batch silently.
        //   - Inserting/reloading an item in a deleted section: already
        //     rejected by `canReconcile`'s existing total-count check.
        //
        // The Risk #3 hardening pass is therefore demoted to "defensive only"
        // — keep canReconcile as-is for these scenarios. See
        // CAN_RECONCILE_HARDENING_PLAN.md for the revised assessment.

        // MARK: Risk #4 — move / insert / delete overlap

        .init(
            name: "deleteAtMoveFromIndex",
            risk: "#4 move overlap",
            snapshot: [[.fake(1), .fake(2), .fake(3)]],
            observerCounts: [2],
            paths: CollectionUpdateIndexPaths(
                deletes: [IndexPath(item: 0, section: 0)],
                moves: [(from: IndexPath(item: 0, section: 0),
                         to:   IndexPath(item: 1, section: 0))]
            )
        ),

        .init(
            name: "insertAtMoveToIndex",
            risk: "#4 move overlap",
            snapshot: [[.fake(1), .fake(2)]],
            observerCounts: [3],
            paths: CollectionUpdateIndexPaths(
                inserts: [IndexPath(item: 1, section: 0)],
                moves: [(from: IndexPath(item: 0, section: 0),
                         to:   IndexPath(item: 1, section: 0))]
            )
        ),
    ]
}
