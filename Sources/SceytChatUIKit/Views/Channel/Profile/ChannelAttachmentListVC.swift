//
//  ChannelAttachmentListVC.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelAttachmentListView: CollectionView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    open var noItemsMessage: String? {
        set { noItemsView.noItemsLabel.text = newValue }
        get { noItemsView.noItemsLabel.text }
    }
    open lazy var noItemsView = NoItemsView()
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
    
    open func updateCollectionView(paths: ChannelAttachmentListVM.ChangeItemPaths) {
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
            backgroundView = noItemsView
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

extension ChannelAttachmentListView {

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

public extension ChannelAttachmentListView.Layout {

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

open class NoItemsView: View {
    open lazy var noItemsLabel = UILabel().withoutAutoresizingMask
    
    open override func setupLayout() {
        super.setupLayout()
        
        addSubview(noItemsLabel)
        noItemsLabel.pin(to: self, anchors: [.top(64), .leading(8), .trailing(-8)])
    }

    open override func setupAppearance() {
        backgroundColor = .clear
        noItemsLabel.font = Fonts.regular.withSize(14)
        noItemsLabel.textColor = UIColor.primaryText
        noItemsLabel.textAlignment = .center
        noItemsLabel.contentMode = .top
    }
}
