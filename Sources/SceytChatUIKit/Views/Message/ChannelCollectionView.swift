//
//  ChannelCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelCollectionView: CollectionView {
    
    public required init() {
        super.init(
            frame: UIScreen.main.bounds,
            collectionViewLayout: Components.channelCollectionViewLayout.init()
        )
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func setup() {
        super.setup()
        isPrefetchingEnabled = false
        showsHorizontalScrollIndicator = false
        alwaysBounceVertical = true
        contentInset.top = 0
        clipsToBounds = true
        contentInsetAdjustmentBehavior = .always

        register(Components.outgoingMessageCell)
        register(Components.incomingMessageCell)
        register(Components.messageSectionSeparatorView, kind: .header)
    }
    
    open var layout: ChannelCollectionViewLayout {
        guard let layout = collectionViewLayout as? ChannelCollectionViewLayout else {
            fatalError("Invalid ChatCollectionViewLayout type")
        }
        return layout
    }
    
    public var safeContentSize: CGSize {
        // Don't use contentSize as the collection view's
        // content size might not be set yet.
        collectionViewLayout.collectionViewContentSize
    }
    
    open var visibleContentRect: CGRect {
        let bounds = self.bounds
        let insetBounds = bounds.inset(by: adjustedContentInset)
        return insetBounds
    }
    
    open var lastVisibleAttributes: UICollectionViewLayoutAttributes? {
        let visibleLayoutAttributes = layout.layoutAttributesForElements(in: visibleContentRect) ?? []
        return visibleLayoutAttributes.max(by: { $0.indexPath < $1.indexPath })
    }
    
    open var lastVisibleIndexPath: IndexPath? {
        lastVisibleAttributes?.indexPath
    }

    open override func reloadData() {
        super.reloadData()
    }
    
    open func reloadDataAndKeepOffset() {
        // stop scrolling
        setContentOffset(contentOffset, animated: false)
        
        let beforeContentSize = safeContentSize
        reloadData()
        layoutIfNeeded()
        let afterContentSize = safeContentSize
        
        let newOffset = CGPoint(
            x: contentOffset.x + (afterContentSize.width - beforeContentSize.width),
            y: contentOffset.y + (afterContentSize.height - beforeContentSize.height))
        setContentOffset(newOffset, animated: false)
    }
    
    open func reloadDataAndScrollToBottom() {
        setContentOffset(contentOffset, animated: false)
        reloadData()
        layoutIfNeeded()
        scrollToBottom(animated: false)
    }
    
    open func reloadDataAndScrollTo(indexPath: IndexPath) {
        // stop scrolling
        setContentOffset(contentOffset, animated: false)
        reloadData()
        layoutIfNeeded()
        if collectionViewLayout.layoutAttributesForItem(at: indexPath) != nil {
            scrollToItem(at: indexPath, pos: .top, animated: false)
        }
    }
    
    open func scrollToItem(at indexPath: IndexPath, pos: UICollectionView.ScrollPosition = .top, animated: Bool = true) {
        scrollToItem(at: indexPath, at: pos, animated: animated)
    }
    
    open func scrollToBottom(animated: Bool, animationDuration: TimeInterval = 0.2, completion: ((Bool) -> Void)? = nil) {
        setContentOffset(contentOffset, animated: false)
        let newOffsetY = safeContentSize.height
            - bounds.height
            + contentInset.bottom
        let offsetY = max(-contentInset.top, newOffsetY)
        if animated {
            UIView.animate(
                withDuration: animationDuration
            ){
                self.contentOffset = CGPoint(x: 0, y: offsetY)
            } completion: {
                completion?($0)
            }
        } else {
            self.contentOffset = CGPoint(x: 0, y: offsetY)
            completion?(true)
        }
    }
    
    open func scrollToTop(animated: Bool = true) {
        guard numberOfSections > 0 else { return }
        guard numberOfItems(inSection: numberOfSections - 1) > 0
        else { return }
        let indexPath = IndexPath(
            item: 0,
            section: 0
        )
        scrollToItem(
            at: indexPath,
            at: .top,
            animated: animated
        )
    }
    
    func indexPath(after indexPath: IndexPath) -> IndexPath? {
        var item = indexPath.item + 1
        for section in indexPath.section ..< numberOfSections {
            if item < numberOfItems(inSection: section) {
                return IndexPath(item: item, section: section)
            }
            item = 0
        }
        return nil
    }
        
    func indexPath(before indexPath: IndexPath) -> IndexPath? {
        var item = indexPath.item - 1
        for section in (0...indexPath.section).reversed() {
            if item >= 0 {
                return IndexPath(item: item, section: section)
            }
            if section > 0 {
                item = numberOfItems(inSection: section - 1) - 1
            }
        }
        return nil
    }
}

public extension ChannelCollectionView {
    
    func findCell(forGesture sender: UIGestureRecognizer) -> UICollectionViewCell? {
        // Collection view is a scroll view; we want to ignore
        // cells that are scrolled offscreen.  So we first check
        // that the collection view contains the gesture location.
        guard contains(gestureRecognizer: sender)
        else { return nil }

        for cell in visibleCells {
            guard cell.contains(gestureRecognizer: sender)
            else { continue }
            return cell
        }
        return nil
    }
    
}
