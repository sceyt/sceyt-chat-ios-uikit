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
                // but the collection view still holds stale cells. Reload whenever the
                // data-source section count no longer matches what the collection view has.
                let currentSections = numberOfSections
                let newSections = dataSource?.numberOfSections?(in: self) ?? 0
                if currentSections != newSections {
                    reloadData()
                }
            } else {
                // UIKit validates batch updates PER SECTION, not in aggregate, so the
                // earlier aggregate checks (total section count + total item count) let
                // through diffs that are +1 in one section and −1 in another and then
                // abort inside performBatchUpdates. Validate every section's post-update
                // count against before ± diff; bail to reloadData() on any mismatch.
                guard canSafelyApply(paths) else {
                    reloadData()
                    updateNoItems()
                    return
                }
                UIView.performWithoutAnimation {
                    performBatchUpdates {
                        if !paths.sectionInserts.isEmpty {
                            insertSections(paths.sectionInserts)
                        }
                        if !paths.sectionDeletes.isEmpty {
                            deleteSections(paths.sectionDeletes)
                        }
                        self.insertItems(at: paths.inserts + paths.moves.map { $0.to })
                        self.reloadItems(at: paths.updates)
                        self.deleteItems(at: paths.deletes + paths.moves.map { $0.from })
                    }
                }
            }

            updateNoItems()
        }

        /// UIKit validates batch updates PER SECTION, not in aggregate. Verify that the
        /// data source's post-update counts equal `before ± diff` for every section; if any
        /// section disagrees — or sections are being added/removed, which shifts section
        /// indices and makes cheap validation unsafe — bail to `reloadData()` instead of
        /// letting `performBatchUpdates` abort with `NSInternalInconsistencyException`.
        private func canSafelyApply(_ paths: ChannelAttachmentListViewModel.ChangeItemPaths) -> Bool {
            // Section add/remove shifts section indices → per-section item math is fragile
            // to validate cheaply. Just reload when the section set changes.
            guard paths.sectionInserts.isEmpty, paths.sectionDeletes.isEmpty else { return false }

            let before = numberOfSections
            let actualSections = dataSource?.numberOfSections?(in: self) ?? 0
            guard before == actualSections else { return false }

            // No section changes → OLD and NEW section indices coincide, so filtering both
            // insert (new-space) and delete (old-space) paths by `.section` is valid.
            let insertsTo = paths.inserts + paths.moves.map { $0.to }
            let deletesFrom = paths.deletes + paths.moves.map { $0.from }
            for s in 0..<before {
                let expected = numberOfItems(inSection: s)
                    + insertsTo.filter { $0.section == s }.count
                    - deletesFrom.filter { $0.section == s }.count
                let actual = dataSource?.collectionView(self, numberOfItemsInSection: s) ?? 0
                if expected != actual { return false }
            }
            return true
        }

        open func updateNoItems() {
            if totalNumberOfItems <= 0 {
                emptyStateView.isHidden = false
            } else {
                emptyStateView.isHidden = true
            }
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
