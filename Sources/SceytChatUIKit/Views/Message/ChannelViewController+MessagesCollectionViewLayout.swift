//
//  ChannelViewController+MessagesCollectionViewLayout.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

public extension ChannelViewController {
    open class MessagesCollectionViewLayout: UICollectionViewFlowLayout {

        // The collection view is mirrored (scaleY: -1) and the data source is
        // presented newest-first, so content-space "top" (y = 0, UI IndexPath(0,0))
        // is the visual bottom. Two consequences the layout relies on:
        //   • Short content naturally hugs the visual bottom — no anchor shift needed.
        //   • Older-message pagination appends at the content end and never moves
        //     the visible items — no offset compensation needed for it.
        //
        // The one case that still needs an atomic offset fix is inserting NEW
        // messages (content-space top inserts) while the user is scrolled up
        // reading history: without compensation the whole viewport would shift.
        // The controller sets this flag before performBatchUpdates; the layout
        // computes the content-height delta in prepare(forCollectionViewUpdates:)
        // and returns a compensating contentOffset from
        // targetContentOffset(forProposedContentOffset:), which UIKit applies
        // atomically with the layout pass — no completion-block correction,
        // no flicker.
        public var isAdjustingForTopInserts: Bool = false
        // VC captures contentSize.height before performBatchUpdates and assigns it
        // here. Used in prepare(forCollectionViewUpdates:) to derive the offset
        // adjustment as (newContentHeight - preBatchContentHeight) — exact
        // regardless of headers, section insets, or line spacing, which a
        // per-item frame sum misses.
        public var preBatchContentHeight: CGFloat = 0
        private var pendingTopInsertOffsetAdjustment: CGFloat = 0

        public required override init() {
            super.init()
        }

        required public init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        open override class var layoutAttributesClass: AnyClass {
            MessagesCollectionViewLayoutAttributes.self
        }

        // MARK: Mirroring

        // The counter-flip for every cell and supplementary view lives in the
        // layout attributes, NOT only at dequeue. UIKit re-applies attributes to
        // on-screen views outside of cellForItemAt — reconfigureItems, the
        // sticky-footer pinning invalidation, batch-update passes — and the
        // default attributes carry an identity transform that would silently
        // un-flip a view that was only transformed at dequeue time. Baking the
        // mirror into the attributes makes every application re-assert it, and
        // also covers subclasses that dequeue/configure views through their own
        // overrides.
        private func mirrored(_ attributes: UICollectionViewLayoutAttributes?) -> UICollectionViewLayoutAttributes? {
            guard let attributes else { return nil }
            let copy = attributes.copy() as! UICollectionViewLayoutAttributes
            copy.transform = .mirrorY
            return copy
        }

        open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            super.layoutAttributesForElements(in: rect)?.compactMap { mirrored($0) }
        }

        open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            mirrored(super.layoutAttributesForItem(at: indexPath))
        }

        open override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            mirrored(super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath))
        }

        open override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            let attributes = mirrored(super.initialLayoutAttributesForAppearingItem(at: itemIndexPath))
            // A message inserted at the newest edge starts one own-height beyond
            // the anchor (visually: rising from behind the input bar) instead of
            // fading in place. Only real inserts get this — items merely shifted
            // by the insert animate their frame change normally. The effect is
            // visible only when the controller runs the batch animated (at-bottom
            // newest inserts); suppressed batches jump straight to final.
            if itemIndexPath == IndexPath(item: 0, section: 0),
               insertedIndexPaths.contains(itemIndexPath),
               let attributes {
                attributes.center.y -= attributes.size.height
                attributes.alpha = 1
            }
            return attributes
        }

        open override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            mirrored(super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath))
        }

        open override func initialLayoutAttributesForAppearingSupplementaryElement(ofKind elementKind: String, at elementIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            mirrored(super.initialLayoutAttributesForAppearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath))
        }

        open override func finalLayoutAttributesForDisappearingSupplementaryElement(ofKind elementKind: String, at elementIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            mirrored(super.finalLayoutAttributesForDisappearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath))
        }

        // Item index paths inserted by the in-flight batch — consumed by
        // initialLayoutAttributesForAppearingItem for the newest-edge slide-in.
        private var insertedIndexPaths: Set<IndexPath> = []

        open override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
            super.prepare(forCollectionViewUpdates: updateItems)
            insertedIndexPaths = Set(
                updateItems.compactMap { item in
                    guard item.updateAction == .insert,
                          let indexPath = item.indexPathAfterUpdate,
                          indexPath.item != NSNotFound
                    else { return nil }
                    return indexPath
                }
            )
            guard isAdjustingForTopInserts else {
                pendingTopInsertOffsetAdjustment = 0
                return
            }
            // contentSize delta is exact for pure top-inserts (no deletes above the
            // anchor), which is what isAdjustingForTopInserts gates. Robust to
            // header padding, section insets, and line spacing that per-item
            // frame.height sums miss.
            let newContentHeight = collectionViewContentSize.height
            let delta = newContentHeight - preBatchContentHeight
            pendingTopInsertOffsetAdjustment = max(0, delta)
        }

        open override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
            guard pendingTopInsertOffsetAdjustment != 0 else {
                return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
            }
            let adjusted = CGPoint(
                x: proposedContentOffset.x,
                y: proposedContentOffset.y + pendingTopInsertOffsetAdjustment
            )
            return adjusted
        }

        open override func finalizeCollectionViewUpdates() {
            insertedIndexPaths.removeAll()
            pendingTopInsertOffsetAdjustment = 0
            preBatchContentHeight = 0
            isAdjustingForTopInserts = false
            super.finalizeCollectionViewUpdates()
        }
    }
}
