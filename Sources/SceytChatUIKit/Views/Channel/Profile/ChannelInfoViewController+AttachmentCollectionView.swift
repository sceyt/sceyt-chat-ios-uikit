//
//  ChannelInfoViewController+AttachmentCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class AttachmentCollectionView: CollectionView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        open var noItemsMessage: String? {
            set { emptyStateView.title = newValue }
            get { emptyStateView.title }
        }
        open var noItemsMessageSubTitle: String? {
            set { emptyStateView.message = newValue }
            get { emptyStateView.message }
        }
        open var noItemsIcon: UIImage? {
            set { emptyStateView.icon = newValue }
            get { emptyStateView.icon }
        }

        open lazy var emptyStateView = EmptyStateStackView()
            .withoutAutoresizingMask

        /// The view model whose load state gates the empty state. Subclasses each hold
        /// their own concretely named view model; this is the one thing the base class
        /// needs from it. `nil` for subclasses that have none — `GroupCollectionView`
        /// drives its own query — which keeps the empty state ungated for them.
        open var attachmentViewModel: (any ChannelAttachmentListViewModelProviding)? { nil }

        open var shouldReceiveTouch: (() -> Bool)?
        public lazy var scrollingDecelerator = ScrollingDecelerator(scrollView: self)
        
        open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            shouldReceiveTouch?() ?? true
        }
        
        open override func setup() {
            super.setup()

            self.addSubview(emptyStateView)
            emptyStateView.pin(to: self, anchors: [.centerX, .top(50), .leading(16, .greaterThanOrEqual)])
            emptyStateView.isHidden = true

            isPrefetchingEnabled = false
            bounces = true
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
        }
        
        open override func setupDone() {
            super.setupDone()
            
            updateNoItems()
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            
            // ⚠️ DO NOT CALL invalidateLayout() directly inside layoutSubviews
            // Originally this was added to force layout recalculation when itemSize.width == 0,
            // but calling invalidateLayout() inside layoutSubviews creates a risk of infinite recursion
            // if the collectionViewLayout's itemSize is not yet resolved.
            //
            // If you need to force invalidation when itemSize is zero,
            // schedule it on the next runloop instead:
            // DispatchQueue.main.async { self?.collectionViewLayout.invalidateLayout() }
            //
            // This avoids dangerous layout loops and app freeze.
            if (collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize.width == 0 {
                collectionViewLayout.invalidateLayout()
            }
        }
        
        open func updateCollectionView(paths: ChannelAttachmentListViewModel.ChangeItemPaths) {
            if superview == nil || visibleCells.isEmpty {
                reloadData()
            } else if paths.isEmpty {
                // restartObserver (triggered by search) delivers an empty ChangeItemPaths when
                // the new result set has no overlap with the previous one (e.g. going from N
                // results to 0 after narrowing a query). There are no diff operations to apply,
                // but the collection view still holds stale cells, so reload whenever what it
                // renders no longer matches what the data source now reports — item counts as
                // well as section counts, since a search can narrow a section without changing
                // how many sections there are.
                guard let counts = renderedAndSourceCounts(), counts.rendered == counts.source
                else {
                    reloadData()
                    updateNoItems()
                    return
                }
            } else {
                // A `.move` is applied as delete-from + insert-to, so the two index spaces are
                // flattened here once and validated together below.
                let deletes = paths.deletes + paths.moves.map { $0.from }
                let inserts = paths.inserts + paths.moves.map { $0.to }
                let updates = Array(Set(paths.updates))

                guard canSafelyApply(deletes: deletes, inserts: inserts, updates: updates, paths: paths)
                else {
                    reloadData()
                    updateNoItems()
                    return
                }

                UIView.performWithoutAnimation {
                    performBatchUpdates {
                        self.insertItems(at: inserts)
                        self.reloadItems(at: updates)
                        self.deleteItems(at: deletes)
                    }
                }
            }

            updateNoItems()
        }

        private func renderedAndSourceCounts() -> (rendered: [Int], source: [Int])? {
            let sectionCount = numberOfSections
            guard sectionCount == (dataSource?.numberOfSections?(in: self) ?? 0) else { return nil }
            var rendered = [Int](repeating: 0, count: sectionCount)
            var source = [Int](repeating: 0, count: sectionCount)
            for s in 0 ..< sectionCount {
                rendered[s] = numberOfItems(inSection: s)
                source[s] = dataSource?.collectionView(self, numberOfItemsInSection: s) ?? 0
            }
            return (rendered, source)
        }

        private func canSafelyApply(
            deletes: [IndexPath],
            inserts: [IndexPath],
            updates: [IndexPath],
            paths: ChannelAttachmentListViewModel.ChangeItemPaths
        ) -> Bool {
            // Section add/remove shifts section indices → per-section item math is fragile
            // to validate cheaply. Just reload when the section set changes.
            guard paths.sectionInserts.isEmpty, paths.sectionDeletes.isEmpty else { return false }

            guard let counts = renderedAndSourceCounts() else { return false }
            let before = counts.rendered
            let after = counts.source
            let sectionCount = before.count

            // The same index path listed twice in one batch is an abort on its own.
            guard Set(deletes).count == deletes.count, Set(inserts).count == inserts.count
            else { return false }

            // A row cannot be reloaded and structurally changed in the same batch.
            let deleteSet = Set(deletes), insertSet = Set(inserts)
            guard updates.allSatisfy({ !deleteSet.contains($0) && !insertSet.contains($0) })
            else { return false }

            func addressable(_ indexPath: IndexPath) -> Bool {
                indexPath.section >= 0 && indexPath.section < sectionCount && indexPath.item >= 0
            }

            // Deletes address the OLD index space.
            var deletesPerSection = [Int](repeating: 0, count: sectionCount)
            for indexPath in deletes {
                guard addressable(indexPath), indexPath.item < before[indexPath.section]
                else { return false }
                deletesPerSection[indexPath.section] += 1
            }

            // Inserts address the NEW index space.
            var insertsPerSection = [Int](repeating: 0, count: sectionCount)
            for indexPath in inserts {
                guard addressable(indexPath), indexPath.item < after[indexPath.section]
                else { return false }
                insertsPerSection[indexPath.section] += 1
            }

            // A reload is applied as delete-then-insert at the same index path, so it has to be
            // addressable in both spaces.
            for indexPath in updates {
                guard addressable(indexPath),
                      indexPath.item < before[indexPath.section],
                      indexPath.item < after[indexPath.section]
                else { return false }
            }

            // UIKit validates PER SECTION, not in aggregate: an aggregate check passes when one
            // section is +1 and another is −1, and then aborts.
            for s in 0 ..< sectionCount
            where before[s] + insertsPerSection[s] - deletesPerSection[s] != after[s] {
                return false
            }

            return true
        }

        open func updateNoItems() {
            // Before the first server page has come back, an empty list means "not loaded
            // yet", not "nothing here": the database starts empty on a channel whose
            // attachments have never been synced, so deciding from the item count alone
            // put "No Media" up over a channel that does have media — until the fetch
            // landed and replaced it with a full grid. Keep the placeholder hidden until
            // the fetch has actually reported back.
            let hasLoadedInitialAttachments = attachmentViewModel?.hasLoadedInitialAttachments ?? true
            emptyStateView.isHidden = totalNumberOfItems > 0 || !hasLoadedInitialAttachments
        }
        
        open var onScrollViewDidScroll: ((UIScrollView) -> Void)?
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            onScrollViewDidScroll?(scrollView)
            
            if scrollView.contentOffset.y < 0 {
                scrollView.contentOffset.y = 0
            }
        }
    }
}

extension ChannelInfoViewController.AttachmentCollectionView {

    open class Layout: UICollectionViewFlowLayout {
        public let settings: Settings

        public required init(settings: Settings) {
            self.settings = settings
            super.init()
            
            if settings.sectionInset != .zero {
                sectionInset = settings.sectionInset
            }
            if !settings.estimatedItemSize.isNan {
                estimatedItemSize = settings.estimatedItemSize
            }
            if !settings.itemSize.isNan {
                itemSize = settings.itemSize
            }
            if !settings.interitemSpacing.isNaN {
                minimumInteritemSpacing = settings.interitemSpacing
            }
            if !settings.lineSpacing.isNaN {
                minimumLineSpacing = settings.lineSpacing
            }
            
            sectionHeadersPinToVisibleBounds = settings.sectionHeadersPinToVisibleBounds
        }

        public required init?(coder: NSCoder) {
            settings = .init()
            super.init(coder: coder)
        }
        
        open override func invalidateLayout() {
            super.invalidateLayout()
        }
    }
}

public extension ChannelInfoViewController.AttachmentCollectionView.Layout {

    struct Settings {
        public let sectionInset: UIEdgeInsets
        public let interitemSpacing: CGFloat
        public let lineSpacing: CGFloat
        public let estimatedItemSize: CGSize
        public let itemSize: CGSize
        public let sectionHeadersPinToVisibleBounds: Bool

        public init(sectionInset: UIEdgeInsets = .zero,
                    interitemSpacing: CGFloat = .nan,
                    lineSpacing: CGFloat = .nan,
                    estimatedItemSize: CGSize = .init(width: CGFloat.nan, height: .nan),
                    itemSize: CGSize = .init(width: CGFloat.nan, height: .nan),
                    sectionHeadersPinToVisibleBounds: Bool = false
        ) {
            self.sectionInset = sectionInset
            self.interitemSpacing = interitemSpacing
            self.lineSpacing = lineSpacing
            self.estimatedItemSize = estimatedItemSize
            self.itemSize = itemSize
            self.sectionHeadersPinToVisibleBounds = sectionHeadersPinToVisibleBounds
        }
    }
}
