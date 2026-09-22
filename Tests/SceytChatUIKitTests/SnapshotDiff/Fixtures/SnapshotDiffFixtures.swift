//
//  SnapshotDiffFixtures.swift
//  SceytChatUIKitTests
//
//  Fixtures and helpers for the Phase 2 snapshot-diff property tests:
//
//  • `randomSnapshot()`           — synthesizes random `AppliedSnapshot`
//                                   values for property testing.
//  • `applyDiffStructurally(_:)`  — reference simulator that applies a
//                                   `SnapshotDiff` to an `AppliedSnapshot`
//                                   the way UIKit's `performBatchUpdates`
//                                   would. Used by the property test that
//                                   verifies `applyDiff(diff(A → B), A) == B`.
//

@testable import SceytChatUIKit
import SceytChat
import Foundation

// MARK: - Random snapshot generation

internal enum SnapshotRandomizer {

    /// Build a random `AppliedSnapshot` for property testing.
    ///
    /// Distribution:
    ///   • 0–4 sections (`SectionId(name: <int>)`)
    ///   • 0–6 items per section (`Key(messageId: <int>)`)
    /// Section ids and message ids are drawn from a SHARED pool so two
    /// randomly-generated snapshots can have overlapping sections / items,
    /// which exercises the diff's identity-matching path more often than a
    /// uniform random would.
    internal static func randomSnapshot(
        sectionPool: ClosedRange<Int> = 1...8,
        itemPool: ClosedRange<MessageId> = 1...32,
        maxSections: Int = 4,
        maxItemsPerSection: Int = 6
    ) -> ChannelViewController.AppliedSnapshot {
        let sectionCount = Int.random(in: 0...maxSections)
        guard sectionCount > 0 else {
            return .empty
        }
        // Pick unique section ids in ascending order to roughly match what
        // the observer would emit (sections are sorted by daySectionIdentifier).
        var pickedSections = Set<Int>()
        while pickedSections.count < sectionCount {
            pickedSections.insert(Int.random(in: sectionPool))
        }
        let sectionIds = pickedSections.sorted().map {
            ChannelViewModel.SectionId(name: AnyHashable($0))
        }
        var items: [[ChannelViewModel.Key]] = []
        items.reserveCapacity(sectionCount)
        var usedItemIds = Set<MessageId>()
        for _ in 0..<sectionCount {
            let n = Int.random(in: 0...maxItemsPerSection)
            var section: [ChannelViewModel.Key] = []
            section.reserveCapacity(n)
            while section.count < n {
                let candidate = MessageId.random(in: itemPool)
                if usedItemIds.insert(candidate).inserted {
                    section.append(ChannelViewModel.Key(messageId: candidate))
                }
            }
            items.append(section)
        }
        return ChannelViewController.AppliedSnapshot(sections: sectionIds, items: items)
    }
}

// MARK: - Reference simulator

internal enum SnapshotDiffSimulator {

    /// Apply a `SnapshotDiff` to `old` and return the resulting snapshot, as if
    /// `performBatchUpdates` had run. Used by the property test that asserts
    /// `applyDiff(diff(A → B), A) == B`.
    ///
    /// Items in newly-inserted sections come from `fresh` directly — UIKit
    /// reads them from the data source after the batch via
    /// `numberOfItemsInSection`, which the production code achieves by
    /// assigning `appliedSnapshot = newSnapshot` inside the updates block.
    /// Items in surviving sections are computed from `old`'s items + the
    /// per-section diff ops — this is what verifies the diff is correct.
    internal static func applyDiffStructurally(
        _ diff: ChannelViewController.SnapshotDiff,
        to old: ChannelViewController.AppliedSnapshot,
        fresh: ChannelViewController.AppliedSnapshot
    ) -> ChannelViewController.AppliedSnapshot {

        let deletedSectionSet = Set(diff.sectionDeletes)
        let insertSet = Set(diff.sectionInserts)

        var newSectionIndex: [ChannelViewModel.SectionId: Int] = [:]
        newSectionIndex.reserveCapacity(fresh.sections.count)
        for (i, id) in fresh.sections.enumerated() {
            newSectionIndex[id] = i
        }

        // Compute per-section transition for surviving sections.
        var survivingSectionItems: [Int: [ChannelViewModel.Key]] = [:]
        for (oldS, sectionId) in old.sections.enumerated() {
            guard !deletedSectionSet.contains(oldS) else { continue }
            guard let newS = newSectionIndex[sectionId] else { continue }

            let oldItems = old.items[oldS]
            let perSectionDeletes: Set<Int> = Set(
                diff.deletes.filter { $0.section == oldS }.map(\.item)
            )
            let perSectionMoveFroms: Set<Int> = Set(
                diff.moves
                    .filter { $0.from.section == oldS && $0.to.section == newS }
                    .map(\.from.item)
            )
            let removed = perSectionDeletes.union(perSectionMoveFroms)

            // Drop removed items, preserve survivor order.
            var survivors: [ChannelViewModel.Key] = []
            survivors.reserveCapacity(oldItems.count - removed.count)
            for (i, key) in oldItems.enumerated() where !removed.contains(i) {
                survivors.append(key)
            }

            // Build post-state insertions: inserts pull keys from `fresh`,
            // move-tos pull keys from `oldItems` (preserving identity).
            struct Insertion { let to: Int; let key: ChannelViewModel.Key }
            var insertions: [Insertion] = []
            for ip in diff.inserts where ip.section == newS {
                insertions.append(.init(to: ip.item, key: fresh.items[newS][ip.item]))
            }
            for move in diff.moves
            where move.from.section == oldS && move.to.section == newS {
                insertions.append(.init(to: move.to.item, key: oldItems[move.from.item]))
            }
            insertions.sort { $0.to < $1.to }

            for ins in insertions {
                let target = min(ins.to, survivors.count)
                survivors.insert(ins.key, at: target)
            }

            survivingSectionItems[newS] = survivors
        }

        // Assemble final snapshot in post-state order.
        var finalSections: [ChannelViewModel.SectionId] = []
        var finalItems: [[ChannelViewModel.Key]] = []
        finalSections.reserveCapacity(fresh.sections.count)
        finalItems.reserveCapacity(fresh.sections.count)
        for newS in 0..<fresh.sections.count {
            finalSections.append(fresh.sections[newS])
            if insertSet.contains(newS) {
                // Newly-inserted section — items come from fresh
                // (UIKit pulls them via numberOfItemsInSection post-batch).
                finalItems.append(fresh.items[newS])
            } else {
                // Surviving section — items reconstructed via per-section diff.
                finalItems.append(survivingSectionItems[newS] ?? [])
            }
        }
        return ChannelViewController.AppliedSnapshot(
            sections: finalSections,
            items: finalItems
        )
    }
}
