//
//  ChannelViewController+MessagesCollectionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKitObjCSupport

public extension ChannelViewController {
    open class MessagesCollectionView: CollectionView {
        
        /// A flag to indicate if `performBatchUpdates` is currently in progress
        private var isPerformBatchUpdates = false
        /// A flag to delay `reloadData` if called during batch updates
        private var needsReloadData = false
        
        public required init() {
            super.init(
                frame: UIScreen.main.bounds,
                collectionViewLayout: Components.channelMessagesCollectionViewLayout.init()
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
            
            register(Components.channelSystemMessageCell)
            register(Components.channelOutgoingMessageCell)
            register(Components.channelIncomingMessageCell)
            register(Components.channelDateSeparatorView, kind: .header)
        }
        
        open var layout: ChannelViewController.MessagesCollectionViewLayout {
            guard let layout = collectionViewLayout as? ChannelViewController.MessagesCollectionViewLayout else {
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
        
        open var visibleAttributes: [UICollectionViewLayoutAttributes] {
            let visibleLayoutAttributes = layout.layoutAttributesForElements(in: visibleContentRect) ?? []
            return visibleLayoutAttributes
        }
        
        open var lastVisibleAttributes: UICollectionViewLayoutAttributes? {
            let visibleLayoutAttributes = layout.layoutAttributesForElements(in: visibleContentRect) ?? []
            return visibleLayoutAttributes.max(by: { $0.indexPath < $1.indexPath })
        }
        
        open var lastVisibleIndexPath: IndexPath? {
            lastVisibleAttributes?.indexPath
        }
        
        /// Wraps `performBatchUpdates` with three layers of safety:
        ///   1. State tracking via `isPerformBatchUpdates` so a `reloadData`
        ///      arriving mid-batch is deferred (UIKit doesn't tolerate it).
        ///   2. An `NSException` catch (`ObjCExceptionCatcher`) — Phase 5 of
        ///      `SNAPSHOT_DIFF_MIGRATION_PLAN.md`. Post-Phase-1–4 the diff is
        ///      consistent by construction so UIKit should never raise, but
        ///      undiscovered UIKit bugs would otherwise crash the app.
        ///   3. A reload fallback if the catch fires — degrades to a single
        ///      `reloadData()` so the user sees correct content (no animation)
        ///      rather than a crash.
        open func performUpdates(_ updates: @escaping (() -> Void), completion: ((Bool) -> Void)? = nil) {
            isPerformBatchUpdates = true

            let exception = ObjCExceptionCatcher.catching { [weak self] in
                guard let self else { return }
                self.performBatchUpdates {
                    updates()
                } completion: { [weak self] finished in
                    // Ensure we're back on the main queue before resetting flags and doing reload
                    DispatchQueue.main.async { [weak self] in
                        if let self {
                            self.isPerformBatchUpdates = false
                            if self.needsReloadData {
                                // Defer actual reload until batch updates are done
                                self.reloadData()
                                // Ensure layout is updated immediately without waiting for next runloop
                                self.layoutIfNeeded()
                            }
                        }
                        completion?(finished)
                    }
                }
            }

            if let exception {
                // Post-Phase-1–4 this should never fire — every diff is
                // consistent by construction. If it does, the diff is a
                // regression we want to find in production logs.
                // Reload to recover deterministically.
                logger.error("""
                    performBatchUpdates raised \(exception.name.rawValue): \
                    \(exception.reason ?? "<no reason>")
                    """)
                isPerformBatchUpdates = false
                super.reloadData()
                layoutIfNeeded()
                completion?(false)
            }
        }

        /// Override reloadData to prevent crashes if called during performBatchUpdates
        open override func reloadData() {
            // If batch updates are in progress, defer the reload
            if isPerformBatchUpdates {
                needsReloadData = true
                return
            }
            // Safe to reload immediately
            super.reloadData()
            // Force layout update now to avoid visual glitches or async issues
            layoutIfNeeded()
            needsReloadData = false
        }

        open func reloadDataAndKeepOffset() {
            // stop scrolling
            setContentOffset(contentOffset, animated: false)

            let beforeContentSize = safeContentSize
            reloadData()
            let afterContentSize = safeContentSize

            let newOffset = CGPoint(
                x: max(0, contentOffset.x + (afterContentSize.width - beforeContentSize.width)),
                y: max(0, contentOffset.y + (afterContentSize.height - beforeContentSize.height))
            )
            setContentOffset(newOffset, animated: false)
        }

        open func reloadDataAndScrollToBottom(animated: Bool = false) {
            setContentOffset(contentOffset, animated: false)
            reloadData()
            scrollToBottom(animated: animated)
        }

        open func reloadDataAndScrollTo(
            indexPath: IndexPath,
            pos: UICollectionView.ScrollPosition = .top,
            animated: Bool = false
        ) {
            reloadDataAndKeepOffset()
            if contains(indexPath: indexPath) {
                scrollToItem(at: indexPath, pos: pos, animated: animated)
            }
        }

        open func scrollToItem(at indexPath: IndexPath, pos: UICollectionView.ScrollPosition = .top, animated: Bool = true) {
            if contains(indexPath: indexPath) {
                scrollToItem(at: indexPath, at: pos, animated: animated)
            } else {
#if DEBUG
                //            fatalError("scrollToItem at: \(indexPath) out-of-bounds")
#endif
            }
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
                    super.contentOffset = CGPoint(x: 0, y: offsetY)
                    //                super.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
                } completion: {
                    completion?($0)
                }
                //            super.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
                //            completion?(true)
            } else {
                super.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
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
        
        func contains(indexPath: IndexPath) -> Bool {
            if indexPath.section < numberOfSections,
               indexPath.item < numberOfItems(inSection: indexPath.section) {
                return true
            }
            return false
        }
    }
}

public extension ChannelViewController.MessagesCollectionView {
    
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
