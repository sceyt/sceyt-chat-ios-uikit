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
            set { emptyStatView.titleLabel.text = newValue }
            get { emptyStatView.titleLabel.text }
        }
        open lazy var emptyStatView = EmptyStateView()
        open var shouldReceiveTouch: (() -> Bool)?
        public lazy var scrollingDecelerator = ScrollingDecelerator(scrollView: self)
        
        open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            shouldReceiveTouch?() ?? true
        }
        
        open override func setup() {
            super.setup()
            
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
            
            if (collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize.width == 0 {
                collectionViewLayout.invalidateLayout()
            }
        }
        
        open func updateCollectionView(paths: ChannelAttachmentListViewModel.ChangeItemPaths) {
            if superview == nil || visibleCells.isEmpty {
                reloadData()
            } else if !paths.isEmpty {
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
        
        open func updateNoItems() {
            if totalNumberOfItems <= 0 {
                backgroundView = emptyStatView
            } else {
                backgroundView = nil
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
                    estimatedItemSize: CGSize = .nan,
                    itemSize: CGSize = .nan,
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
