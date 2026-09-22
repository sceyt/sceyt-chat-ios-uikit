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

        /// Which visual edge holds the newest message. The controller pushes
        /// `appearance.messageListOrder` here in `setupAppearance()`; changing it
        /// re-applies the mirror, relayouts and re-anchors to the newest message.
        open var messageListOrder: ChannelViewController.MessageListOrder = .newestAtBottom {
            didSet {
                guard oldValue != messageListOrder else { return }
                applyMessageListOrder()
                reloadData()
                // "bottom" means the newest edge in both orders.
                scrollToBottom(animated: false)
            }
        }

        /// Pushes the current order into the view's own transform and into the
        /// layout, which bakes it into every attribute it hands back.
        open func applyMessageListOrder() {
            transform = messageListOrder.contentTransform
            layout.messageListOrder = messageListOrder
            collectionViewLayout.invalidateLayout()
        }


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
            clipsToBounds = true
            // Content-space top (offset ≈ 0) always holds the newest message. In
            // `.newestAtBottom` the view is mirrored so that edge renders at the
            // visual bottom, and every cell/supplementary view is flipped back at
            // dequeue; in `.newestAtTop` the view is upright. Either way the
            // controller manages contentInset manually — safe-area-driven inset
            // adjustment would pad the wrong edges in the mirrored space.
            applyMessageListOrder()
            contentInsetAdjustmentBehavior = .never

            register(Components.channelSystemMessageCell)
            register(Components.channelOutgoingMessageCell)
            register(Components.channelIncomingMessageCell)
            // The date separator renders as a footer in `.newestAtBottom` and as a
            // header in `.newestAtTop`, so both kinds are registered. Registering
            // both also guards subclasses that give the unused kind a non-zero
            // reference size — an unregistered kind would crash the dequeue.
            register(Components.channelDateSeparatorView, kind: .footer)
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

        /// Attributes of the newest visible message. The list is presented
        /// newest-first in both orders, so that is the MIN index path.
        open var lastVisibleAttributes: UICollectionViewLayoutAttributes? {
            let visibleLayoutAttributes = layout.layoutAttributesForElements(in: visibleContentRect) ?? []
            return visibleLayoutAttributes
                .filter { $0.representedElementCategory == .cell }
                .min(by: { $0.indexPath < $1.indexPath })
        }

        open var lastVisibleIndexPath: IndexPath? {
            lastVisibleAttributes?.indexPath
        }

        /// Offset of the newest edge — the visual bottom in `.newestAtBottom`, the
        /// visual top in `.newestAtTop`. It is the content-space origin in both.
        public var bottomContentOffsetY: CGFloat {
            -adjustedContentInset.top
        }

        /// Offset of the oldest edge — the content-space end in both orders.
        public var maxContentOffsetY: CGFloat {
            max(
                bottomContentOffsetY,
                collectionViewLayout.collectionViewContentSize.height
                    - bounds.height
                    + adjustedContentInset.bottom
            )
        }

        /// Whether the viewport rests at (or within `threshold` points of) the
        /// newest message. Because the newest edge is the content-space origin in
        /// both orders this is simply an offset check — content inserted at that
        /// edge while this is true stays anchored on screen without any explicit
        /// scrolling.
        public func isAtBottom(threshold: CGFloat = 30) -> Bool {
            contentOffset.y <= bottomContentOffsetY + threshold
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

            // The offset is anchored at the newest edge and older content grows
            // away from it (toward larger y) in both orders, so a plain reload
            // already keeps the visual position. Just clamp into the new range.
            reloadData()
            let clampedY = min(max(contentOffset.y, bottomContentOffsetY), maxContentOffsetY)
            if clampedY != contentOffset.y {
                setContentOffset(CGPoint(x: 0, y: clampedY), animated: false)
            }
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

        /// Positions the unread ("New messages") separator bar a fixed distance
        /// inside the viewport's OLDER-facing edge, so the rest of the screen fills
        /// with unread messages.
        ///
        /// The bar always renders on the anchor cell's newer-facing side, which in
        /// content space is `[frame.minY, frame.minY + separatorHeight]` in both
        /// orders — mirrored the cell is flipped, upright the bar is pinned to the
        /// cell's top. The older-facing viewport edge is likewise the content-space
        /// far end in both orders, so this one formula covers them. The target is
        /// derived from the cell's layout frame, not from scrollToItem semantics
        /// (which can only align cell edges, leaving the bar's final spot dependent
        /// on the anchor bubble's height).
        open func scrollToUnreadSeparator(
            at indexPath: IndexPath,
            separatorHeight: CGFloat,
            offsetFromOlderEdge: CGFloat
        ) {
            guard contains(indexPath: indexPath),
                  let attrs = collectionViewLayout.layoutAttributesForItem(at: indexPath)
            else { return }
            // Older-facing edge in content space: contentOffset.y + bounds.height
            // - adjustedContentInset.bottom. Place the bar's older-facing edge
            // (frame.minY + separatorHeight) offsetFromOlderEdge inside it. The
            // clamp handles the few-unread case: the list rests at the newest
            // edge and the bar falls wherever it naturally sits mid-screen.
            let targetY = attrs.frame.minY + separatorHeight + offsetFromOlderEdge
                - bounds.height + adjustedContentInset.bottom
            let clampedY = min(max(targetY, bottomContentOffsetY), maxContentOffsetY)
            setContentOffset(CGPoint(x: 0, y: clampedY), animated: false)
        }

        open func reloadDataAndScrollToUnreadSeparator(
            at indexPath: IndexPath,
            separatorHeight: CGFloat,
            offsetFromOlderEdge: CGFloat
        ) {
            reloadDataAndKeepOffset()
            scrollToUnreadSeparator(
                at: indexPath,
                separatorHeight: separatorHeight,
                offsetFromOlderEdge: offsetFromOlderEdge
            )
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
            // The newest message lives at the content-space top in both orders,
            // so "bottom" is a constant offset — no contentSize math needed.
            let offsetY = bottomContentOffsetY
            if animated {
                UIView.animate(
                    withDuration: animationDuration
                ){
                    super.contentOffset = CGPoint(x: 0, y: offsetY)
                } completion: {
                    completion?($0)
                }
            } else {
                super.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
                completion?(true)
            }
        }

        open func scrollToTop(animated: Bool = true) {
            // Oldest message = end of the content in both orders.
            setContentOffset(CGPoint(x: 0, y: maxContentOffsetY), animated: animated)
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

