//
//  PerformBatchUpdatesIntegrationTests.swift
//  SceytChatUIKitTests
//
//  Tier 2 — proves that every malformed fixture in `MalformedPathFixtures` is
//  a REAL UIKit crash, not a theoretical one. For each fixture, two assertions:
//
//    A. `canReconcile` rejects it pre-flight (would prevent the crash in prod).
//    B. Bypassing the gate and applying the fixture via `performBatchUpdates`
//       on a real `UICollectionView` raises NSException.
//
//  This is what makes the Tier 1 negative tests trustworthy: every red test
//  in CanReconcileTests has a corresponding fixture here, and we prove that
//  fixture would in fact crash UIKit if the gate let it through.
//

@testable import SceytChatUIKit
import XCTest
import UIKit
import SceytChatUIKitObjCSupport

final class PerformBatchUpdatesIntegrationTests: XCTestCase {

    // MARK: - The single iterating test

    /// For every fixture: assert (A) the gate rejects, (B) UIKit would crash.
    func test_everyMalformedFixture_isRejectedAndWouldCrashUIKit() {
        for fixture in MalformedPathFixtures.all {

            // A. canReconcile must reject it. If the gate doesn't reject, the
            // fixture would reach UIKit in production and crash users.
            let gateAccepts = ChannelViewController.canReconcile(
                snapshot: fixture.snapshot,
                observerSectionCounts: fixture.observerCounts,
                paths: fixture.paths
            )
            XCTAssertFalse(
                gateAccepts,
                "[\(fixture.risk)] canReconcile must reject \(fixture.name); fixture currently slips through the gate."
            )

            // B. Bypassing the gate, performBatchUpdates must throw NSException.
            // If it doesn't, the fixture is not actually a UIKit crash — remove
            // it from the catalog or fix it.
            let cv = makeMinimalCollectionView(initialSnapshot: fixture.snapshot)
            let dataSource = cv.dataSource as! CountTrackingDataSource

            let thrown = ObjCExceptionCatcher.catching {
                cv.performBatchUpdates({
                    self.applyRawToCollectionView(fixture.paths, on: cv)
                    dataSource.applyPaths(fixture.paths)
                }, completion: nil)
            }
            XCTAssertNotNil(
                thrown,
                """
                [\(fixture.risk)] \(fixture.name) did not trigger an NSException. \
                Either the fixture is not actually a real UIKit crash (remove it \
                from MalformedPathFixtures), or UIKit's behavior changed and the \
                fixture needs to be updated.
                """
            )
        }
    }

    // MARK: - Test infrastructure

    /// Build a minimal UICollectionView whose data source returns counts
    /// matching `initialSnapshot`. We never render cells, so cell registration
    /// is a no-op placeholder.
    private func makeMinimalCollectionView(
        initialSnapshot: [[ChannelViewModel.Key]]
    ) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 50, height: 50)
        let cv = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480),
            collectionViewLayout: layout
        )
        cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        let ds = CountTrackingDataSource()
        ds.sectionCounts = initialSnapshot.map(\.count)
        cv.dataSource = ds
        // Retain the data source for the lifetime of the collection view via
        // associated object — collection view holds dataSource weakly.
        objc_setAssociatedObject(cv, &dataSourceKey, ds, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        cv.reloadData()
        cv.layoutIfNeeded()
        return cv
    }

    /// Apply the malformed paths to the UICollectionView directly — exactly
    /// the same operations the production `updates` closure performs in
    /// `ChannelViewController.onEvent(.update)`, but without any gate. This
    /// is the bypass that proves each fixture is a real UIKit crash.
    private func applyRawToCollectionView(
        _ paths: CollectionUpdateIndexPaths,
        on cv: UICollectionView
    ) {
        if !paths.sectionInserts.isEmpty {
            cv.insertSections(paths.sectionInserts)
        }
        if !paths.sectionDeletes.isEmpty {
            cv.deleteSections(paths.sectionDeletes)
        }
        cv.insertItems(at: paths.inserts)
        cv.reloadItems(at: paths.reloads)
        cv.deleteItems(at: paths.deletes)
        for move in paths.moves {
            cv.moveItem(at: move.from, to: move.to)
        }
    }
}

// MARK: - CountTrackingDataSource

/// Minimal data source that tracks per-section counts only. The integration
/// test doesn't care about cell content — only that UIKit's batch validation
/// can read pre-batch and post-batch counts. Mutating `sectionCounts` inside
/// the `performBatchUpdates` closure simulates what `appliedSnapshot` does
/// in production.
final class CountTrackingDataSource: NSObject, UICollectionViewDataSource {
    var sectionCounts: [Int] = []

    func numberOfSections(in cv: UICollectionView) -> Int {
        sectionCounts.count
    }

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection s: Int) -> Int {
        guard s >= 0, s < sectionCounts.count else { return 0 }
        return sectionCounts[s]
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        cv.dequeueReusableCell(withReuseIdentifier: "cell", for: ip)
    }

    /// Apply structural ops from `paths` to `sectionCounts`. This keeps the
    /// data source consistent with what UIKit was told happens in the same
    /// batch — analogous to ChannelViewController.applyPathsToSnapshot, but
    /// tracks counts only.
    func applyPaths(_ paths: CollectionUpdateIndexPaths) {
        // Section deletes (descending so earlier indices stay valid).
        for s in paths.sectionDeletes.sorted(by: >) where s < sectionCounts.count {
            sectionCounts.remove(at: s)
        }
        // Section inserts (ascending; clamp to current size).
        for s in paths.sectionInserts.sorted() {
            sectionCounts.insert(0, at: min(s, sectionCounts.count))
        }
        // Per-section item deltas. Inserts +1, deletes -1, cross-section moves
        // shift counts between sections. Intra-section moves are net zero.
        for ip in paths.inserts where ip.section >= 0 && ip.section < sectionCounts.count {
            sectionCounts[ip.section] += 1
        }
        for ip in paths.deletes where ip.section >= 0 && ip.section < sectionCounts.count {
            sectionCounts[ip.section] = max(0, sectionCounts[ip.section] - 1)
        }
        for move in paths.moves where move.from.section != move.to.section {
            if move.from.section >= 0, move.from.section < sectionCounts.count {
                sectionCounts[move.from.section] = max(0, sectionCounts[move.from.section] - 1)
            }
            if move.to.section >= 0, move.to.section < sectionCounts.count {
                sectionCounts[move.to.section] += 1
            }
        }
    }
}

private var dataSourceKey: UInt8 = 0
