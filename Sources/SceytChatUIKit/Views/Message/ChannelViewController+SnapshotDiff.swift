//
//  ChannelViewController+SnapshotDiff.swift
//  SceytChatUIKit
//
//  Phase 2 of the snapshot-diff migration (see SNAPSHOT_DIFF_MIGRATION_PLAN.md).
//
//  Provides the pure-function diff between two `AppliedSnapshot`s. The diff is
//  computed at apply time from the two snapshots, not from observer-emitted
//  paths — which eliminates the class of `performBatchUpdates` crashes caused
//  by paths going stale relative to `appliedSnapshot` (subscription gaps,
//  coalescing races, etc.). The math always balances by construction because
//  it's a pure function of the two snapshots.
//

import Foundation

extension ChannelViewController {

    /// A structural delta between two `AppliedSnapshot`s, expressed in UIKit
    /// batch-update terms (section inserts/deletes, item inserts/deletes/moves,
    /// reloads). All section indices are post-state for inserts/moves.to and
    /// pre-state for deletes/moves.from, matching UIKit's contract for
    /// `performBatchUpdates`.
    internal struct SnapshotDiff: Equatable {
        struct Move: Equatable {
            let from: IndexPath
            let to: IndexPath
        }

        let sectionInserts: IndexSet
        let sectionDeletes: IndexSet
        let inserts: [IndexPath]
        let deletes: [IndexPath]
        let moves: [Move]
        let reloads: [IndexPath]

        static let empty = SnapshotDiff(
            sectionInserts: IndexSet(),
            sectionDeletes: IndexSet(),
            inserts: [],
            deletes: [],
            moves: [],
            reloads: []
        )

        var isEmpty: Bool {
            sectionInserts.isEmpty && sectionDeletes.isEmpty &&
            inserts.isEmpty && deletes.isEmpty && moves.isEmpty && reloads.isEmpty
        }

        /// Project to the legacy `CollectionUpdateIndexPaths` shape so the
        /// existing `canReconcile` static can validate the diff. Used by the
        /// Phase 3 `#if DEBUG` assertion and by Phase 2 property tests.
        func asCollectionUpdateIndexPaths() -> CollectionUpdateIndexPaths {
            CollectionUpdateIndexPaths(
                inserts: inserts,
                reloads: reloads,
                deletes: deletes,
                moves: moves.map { (from: $0.from, to: $0.to) },
                sectionInserts: sectionInserts,
                sectionReloads: IndexSet(),
                sectionDeletes: sectionDeletes
            )
        }
    }

    /// Pure-function diff between two snapshots. Matches sections by identity
    /// (`SectionId`) using `CollectionDifference`; matches items within
    /// surviving sections by `Key` using `CollectionDifference.inferringMoves()`.
    /// Items in newly-inserted sections and in to-be-deleted sections are
    /// implicit (UIKit handles them via the section op).
    ///
    /// Cross-section moves are not detected — they appear as a delete in the
    /// old section + an insert in the new section. This is acceptable for chat
    /// (cross-section moves happen only on clock-skew edits, which are rare).
    internal static func computeDiff(
        from oldSnapshot: AppliedSnapshot,
        to newSnapshot: AppliedSnapshot,
        reloadHints: Set<IndexPath>
    ) -> SnapshotDiff {

        // 1. Section diff — identity-based via stdlib CollectionDifference.
        let sectionDiff = newSnapshot.sections.difference(from: oldSnapshot.sections)
        var sectionInserts = IndexSet()
        var sectionDeletes = IndexSet()
        for change in sectionDiff {
            switch change {
            case let .insert(offset, _, _):
                sectionInserts.insert(offset)
            case let .remove(offset, _, _):
                sectionDeletes.insert(offset)
            }
        }

        // 2. Per-section item diff for sections present in BOTH snapshots.
        var inserts: [IndexPath] = []
        var deletes: [IndexPath] = []
        var moves: [SnapshotDiff.Move] = []

        var newSectionIndex: [ChannelViewModel.SectionId: Int] = [:]
        newSectionIndex.reserveCapacity(newSnapshot.sections.count)
        for (i, id) in newSnapshot.sections.enumerated() {
            newSectionIndex[id] = i
        }

        for (oldS, sectionId) in oldSnapshot.sections.enumerated() {
            guard let newS = newSectionIndex[sectionId] else { continue }
            let oldItems = oldSnapshot.items[oldS]
            let newItems = newSnapshot.items[newS]
            let itemDiff = newItems.difference(from: oldItems).inferringMoves()
            for change in itemDiff {
                switch change {
                case let .insert(offset, _, associatedIndex):
                    if let movedFromIndex = associatedIndex {
                        // Paired with a remove → within-section move.
                        moves.append(.init(
                            from: IndexPath(item: movedFromIndex, section: oldS),
                            to: IndexPath(item: offset, section: newS)
                        ))
                    } else {
                        inserts.append(IndexPath(item: offset, section: newS))
                    }
                case let .remove(offset, _, associatedIndex):
                    if associatedIndex == nil {
                        deletes.append(IndexPath(item: offset, section: oldS))
                    }
                    // else: paired with insert above — recorded as move.
                }
            }
        }

        // 3. Reloads — observer-supplied hints, sanitized to be UIKit-safe.
        //
        // UIKit's `reloadItems(at:)` takes PRE-state index paths and rejects
        // any IP that also appears in `deletes` or as a move-from in the same
        // batch (raises NSInternalInconsistencyException). Observer reload
        // hints are emitted from a snapshot that may not match `oldSnapshot`
        // exactly (subscription gaps, coalesced events), so we have to filter
        // defensively:
        //
        //   a. IP must be a valid pre-state position in `oldSnapshot`.
        //   b. IP must not collide with our deletes or move-froms.
        //   c. The `Key` at that IP must still exist in `newSnapshot` —
        //      otherwise reloading is meaningless (UIKit would crash if it
        //      tried to reload an item that's about to be deleted anyway).
        let preStateDeletes = Set(deletes)
        let preStateMoveFroms = Set(moves.map(\.from))
        let reloads = reloadHints
            .compactMap { ip -> IndexPath? in
                // (a) pre-state bounds
                guard ip.section >= 0,
                      ip.section < oldSnapshot.sectionCount,
                      ip.item >= 0,
                      ip.item < oldSnapshot.items[ip.section].count
                else { return nil }
                // (b) disjoint from deletes/move-froms
                guard !preStateDeletes.contains(ip),
                      !preStateMoveFroms.contains(ip)
                else { return nil }
                // (c) item still present in the post-state, in the same section
                // (cross-section moves are handled as delete+insert, not reload).
                let key = oldSnapshot.items[ip.section][ip.item]
                let sectionId = oldSnapshot.sections[ip.section]
                guard let newS = newSectionIndex[sectionId],
                      newSnapshot.items[newS].contains(key)
                else { return nil }
                return ip
            }
            .sorted()

        return SnapshotDiff(
            sectionInserts: sectionInserts,
            sectionDeletes: sectionDeletes,
            inserts: inserts.sorted(),
            deletes: deletes.sorted(),
            moves: moves,
            reloads: reloads
        )
    }
}
