//
//  PinnedListSnapshotDiffTests.swift
//  SceytChatUIKitTests
//
//  Property tests for
//  `ChannelPinnedMessageListViewController.computeDiff(from:to:)` — the diff the
//  pinned-messages screen turns a pin change into, so an unpin can animate one row
//  away instead of reloading the table.
//
//  The diff is what `performBatchUpdates` is handed, so it has to balance: applying
//  its deletes, inserts and moves to the pre-state row order must reproduce the
//  post-state row order exactly. That is asserted here over randomized snapshot
//  pairs rather than a handful of examples, the way `SnapshotDiffTests` does it for
//  the conversation's own diff.
//
//  Properties under test:
//
//    1. **Identity**: `computeDiff(s, s).isEmpty`
//    2. **Bridge**: applying the diff to `old.ids` yields `new.ids`
//    3. **Disjointness**: `reloads` never names a deleted or moved-from row
//    4. **Versions**: a surviving row whose `contentVersion` moved is always
//       reloaded, at its pre-state index
//

@testable import SceytChatUIKit
import SceytChat
import XCTest

final class PinnedListSnapshotDiffTests: XCTestCase {

    typealias Snapshot = ChannelPinnedMessageListViewController.AppliedSnapshot
    typealias Diff = ChannelPinnedMessageListViewController.SnapshotDiff

    private let iterations = 1_000

    // MARK: - Property 1: identity

    func test_property_diffOfIdentityIsEmpty() {
        for _ in 0 ..< iterations {
            let snapshot = Self.randomSnapshot()
            let diff = ChannelPinnedMessageListViewController.computeDiff(from: snapshot, to: snapshot)
            XCTAssertTrue(diff.isEmpty, "diff(s, s) must be empty; got \(diff)")
            XCTAssertFalse(diff.isStructural)
        }
    }

    // MARK: - Property 2: bridge

    /// The one property `performBatchUpdates` actually checks: what the batch does to
    /// the rows on screen has to land on the rows the view model now describes.
    func test_property_diffBridgesTwoSnapshots() {
        for iteration in 0 ..< iterations {
            let old = Self.randomSnapshot()
            let new = Self.randomSnapshot(sharing: old)
            let diff = ChannelPinnedMessageListViewController.computeDiff(from: old, to: new)

            XCTAssertEqual(
                Self.apply(diff, to: old, new: new),
                new.ids,
                "Iteration \(iteration): applying \(diff) to \(old.ids) must yield \(new.ids)"
            )
            // The arithmetic UIKit aborts on if it does not hold.
            XCTAssertEqual(
                old.count + diff.inserts.count - diff.deletes.count,
                new.count,
                "Iteration \(iteration): old + inserts - deletes must equal new"
            )
        }
    }

    // MARK: - Property 3: disjointness

    /// UIKit refuses a reload path that the same batch also deletes or moves away from.
    func test_property_reloadsAreDisjointFromDeletesAndMoves() {
        for iteration in 0 ..< iterations {
            let old = Self.randomSnapshot()
            let new = Self.randomSnapshot(sharing: old)
            let diff = ChannelPinnedMessageListViewController.computeDiff(from: old, to: new)

            let forbidden = Set(diff.deletes).union(diff.moves.map(\.from))
            XCTAssertTrue(
                Set(diff.reloads).isDisjoint(with: forbidden),
                "Iteration \(iteration): reloads \(diff.reloads) overlap \(forbidden)"
            )
            for row in diff.reloads {
                XCTAssertTrue(old.ids.indices.contains(row), "a reload must be a pre-state row")
            }
        }
    }

    // MARK: - Property 4: versions

    /// A row that stays put but re-measures — the pin above one that just left inherits
    /// the list's first-row spacing — has to be named, because UIKit keeps its cached
    /// height for any row the batch does not mention.
    func test_property_survivingRowWithChangedVersionIsReloaded() {
        for iteration in 0 ..< iterations {
            let old = Self.randomSnapshot()
            let new = Self.randomSnapshot(sharing: old, bumpingVersions: true)
            let diff = ChannelPinnedMessageListViewController.computeDiff(from: old, to: new)

            let movedFrom = Set(diff.moves.map(\.from))
            let deleted = Set(diff.deletes)
            for (row, id) in old.ids.enumerated() where !deleted.contains(row) && !movedFrom.contains(row) {
                guard let newVersion = new.versions[id], newVersion != old.versions[id] else { continue }
                XCTAssertTrue(
                    diff.reloads.contains(row),
                    "Iteration \(iteration): surviving row \(row) (id \(id)) changed version and must be reloaded"
                )
            }
        }
    }

    // MARK: - Worked examples

    func test_unpinningTheMiddleRow_isOneDelete() {
        let old = Self.snapshot(ids: [1, 2, 3])
        let new = Self.snapshot(ids: [1, 3])
        let diff = ChannelPinnedMessageListViewController.computeDiff(from: old, to: new)

        XCTAssertEqual(diff.deletes, [1])
        XCTAssertTrue(diff.inserts.isEmpty)
        XCTAssertTrue(diff.moves.isEmpty)
        XCTAssertTrue(diff.isStructural)
    }

    func test_unpinningTheOnlyRow_isOneDelete() {
        let diff = ChannelPinnedMessageListViewController.computeDiff(
            from: Self.snapshot(ids: [7]),
            to: .empty
        )
        XCTAssertEqual(diff.deletes, [0])
        XCTAssertTrue(diff.inserts.isEmpty)
    }

    func test_aNewPinArrivesAtTheBottom() {
        let diff = ChannelPinnedMessageListViewController.computeDiff(
            from: Self.snapshot(ids: [1, 2]),
            to: Self.snapshot(ids: [1, 2, 3])
        )
        XCTAssertEqual(diff.inserts, [2])
        XCTAssertTrue(diff.deletes.isEmpty)
    }

    /// A pin's own columns changing — an acknowledgement filling in `serverPinId` — must
    /// not spin the table, because nothing a row draws comes from them.
    func test_sameRowsAndVersions_isNoDiffAtAll() {
        let old = Self.snapshot(ids: [1, 2, 3])
        let new = Self.snapshot(ids: [1, 2, 3])
        XCTAssertTrue(ChannelPinnedMessageListViewController.computeDiff(from: old, to: new).isEmpty)
    }

    /// A confirmation re-sorts an optimistic pin, because `serverPinId` leads the sort.
    func test_aReorderedPin_isAMove() {
        let diff = ChannelPinnedMessageListViewController.computeDiff(
            from: Self.snapshot(ids: [1, 2, 3]),
            to: Self.snapshot(ids: [2, 3, 1])
        )
        XCTAssertTrue(diff.isStructural)
        XCTAssertEqual(Self.apply(diff, to: Self.snapshot(ids: [1, 2, 3]), new: Self.snapshot(ids: [2, 3, 1])), [2, 3, 1])
    }

    /// Content changed under every row, nothing moved: reloads only, so the screen takes
    /// its non-animated path.
    func test_versionBumpAlone_isNotStructural() {
        let ids: [Int64] = [1, 2, 3]
        let old = Self.snapshot(ids: ids, version: 1)
        let new = Self.snapshot(ids: ids, version: 2)
        let diff = ChannelPinnedMessageListViewController.computeDiff(from: old, to: new)

        XCTAssertEqual(diff.reloads, [0, 1, 2])
        XCTAssertFalse(diff.isStructural)
        XCTAssertFalse(diff.isEmpty)
    }
}

// MARK: - Snapshot building

private extension PinnedListSnapshotDiffTests {

    /// A snapshot with the given row order. The models are left out: the diff reads only
    /// the ids and the versions, and a `MessageLayoutModel` needs a channel and a message
    /// to exist at all.
    static func snapshot(ids: [Int64], version: UInt = 1) -> Snapshot {
        snapshot(ids: ids, versions: Dictionary(uniqueKeysWithValues: ids.map { ($0, version) }))
    }

    /// `PinnedMessage` is deliberately never named: the SDK exports a type of the same
    /// name, and the module cannot be used to qualify it because `SceytChatUIKit` is also
    /// a class. `.init` in the position of `items`' element type sidesteps both.
    static func snapshot(ids: [Int64], versions: [Int64: UInt]) -> Snapshot {
        Snapshot(
            items: ids.map { tid in
                .init(
                    channelId: 1,
                    messageId: MessageId(tid),
                    messageTid: tid,
                    scope: .forAll,
                    pinnedAt: nil,
                    pinnedUntil: nil,
                    pinnedByUserId: nil,
                    messageCreatedAt: nil,
                    body: "pin \(tid)",
                    messageType: "text",
                    messageState: .none,
                    sender: nil,
                    attachment: nil,
                    syncState: .synced,
                    retryCount: 0,
                    lastAttemptAt: 0
                )
            },
            models: [:],
            versions: versions
        )
    }

    static func randomSnapshot(
        sharing other: Snapshot? = nil,
        bumpingVersions: Bool = false
    ) -> Snapshot {
        // Ids drawn from a small pool, so two snapshots overlap the way two states of one
        // pin set do — otherwise every diff would be "delete everything, insert everything".
        let pool: [Int64] = Array(1 ... 12)
        let count = Int.random(in: 0 ... 8)
        var ids = [Int64]()
        var remaining = pool.shuffled()
        for _ in 0 ..< count where !remaining.isEmpty {
            ids.append(remaining.removeLast())
        }
        var versions = [Int64: UInt]()
        for id in ids {
            if let other, let existing = other.versions[id], !bumpingVersions {
                versions[id] = existing
            } else {
                versions[id] = UInt.random(in: 1 ... 3)
            }
        }
        return snapshot(ids: ids, versions: versions)
    }

    /// Replays the diff against the pre-state row order the way `UITableView` does:
    /// deletes and move-froms in pre-state coordinates, then inserts and move-tos in
    /// post-state ones.
    static func apply(_ diff: Diff, to old: Snapshot, new: Snapshot) -> [Int64] {
        let oldIds = old.ids
        let newIds = new.ids
        let removed = Set(diff.deletes).union(diff.moves.map(\.from))
        var rows = oldIds.enumerated().filter { !removed.contains($0.offset) }.map { $0.element }

        let arrivals = (diff.inserts.map { (row: $0, id: newIds[$0]) }
            + diff.moves.map { (row: $0.to, id: oldIds[$0.from]) })
            .sorted { $0.row < $1.row }
        for arrival in arrivals {
            let row = min(arrival.row, rows.count)
            rows.insert(arrival.id, at: row)
        }
        return rows
    }
}
