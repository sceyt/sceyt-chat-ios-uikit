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

        // Distance to push every item/supplementary down so that, when the natural
        // content height is shorter than the visible area, items pin to the bottom
        // (above the input bar) instead of stacking from the top with empty space below.
        // Zero whenever content already fills or exceeds the visible area.
        public private(set) var bottomAnchorShift: CGFloat = 0

        // When the controller is about to insert older messages at the top, it sets this
        // to true before performBatchUpdates. The layout then computes the total height
        // of inserts in prepare(forCollectionViewUpdates:) and returns a compensating
        // contentOffset from targetContentOffset(forProposedContentOffset:), which UIKit
        // applies atomically with the layout pass. This is the canonical way to keep
        // visible items rooted while content grows above them — no completion-block
        // correction, no flicker.
        public var isAdjustingForTopInserts: Bool = false
        // VC captures contentSize.height before performBatchUpdates and assigns it here.
        // Used in prepare(forCollectionViewUpdates:) to derive the offset adjustment as
        // (newContentHeight - preBatchContentHeight) — exact regardless of headers,
        // section insets, or line spacing, which a per-item frame sum misses.
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

        open override func prepare() {
            super.prepare()
            bottomAnchorShift = computeBottomAnchorShift()
        }

        open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            true
        }

        open override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
            super.invalidateLayout(with: context)
        }

        open override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
            super.prepare(forCollectionViewUpdates: updateItems)
            guard isAdjustingForTopInserts else {
                pendingTopInsertOffsetAdjustment = 0
                return
            }
            // contentSize delta is exact for pure top-inserts (no deletes above the anchor),
            // which is what isAdjustingForTopInserts gates. Robust to header padding,
            // section insets, and line spacing that per-item frame.height sums miss.
            let newContentHeight = collectionViewContentSize.height
            let delta = newContentHeight - preBatchContentHeight
            pendingTopInsertOffsetAdjustment = max(0, delta)

            var summedHeight: CGFloat = 0
            var insertCount = 0
            var sectionInsertCount = 0
            var nilAttrCount = 0
            for item in updateItems {
                guard item.updateAction == .insert,
                      let newIndexPath = item.indexPathAfterUpdate
                else { continue }
                insertCount += 1
                if newIndexPath.item == NSNotFound {
                    sectionInsertCount += 1
                    if let attrs = super.layoutAttributesForSupplementaryView(
                        ofKind: UICollectionView.elementKindSectionHeader,
                        at: IndexPath(item: 0, section: newIndexPath.section)
                    ) {
                        summedHeight += attrs.frame.height
                    } else {
                        nilAttrCount += 1
                    }
                } else if let attrs = super.layoutAttributesForItem(at: newIndexPath) {
                    summedHeight += attrs.frame.height
                } else {
                    nilAttrCount += 1
                }
            }
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
            pendingTopInsertOffsetAdjustment = 0
            preBatchContentHeight = 0
            isAdjustingForTopInserts = false
            super.finalizeCollectionViewUpdates()
        }

        open override var collectionViewContentSize: CGSize {
            var size = super.collectionViewContentSize
            size.height += bottomAnchorShift
            return size
        }

        open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
            let shift = bottomAnchorShift
            guard shift > 0 else {
                return super.layoutAttributesForElements(in: rect)
            }
            let superRect = rect.offsetBy(dx: 0, dy: -shift)
            return super.layoutAttributesForElements(in: superRect)?.map { attrs in
                let copy = attrs.copy() as! UICollectionViewLayoutAttributes
                copy.frame = copy.frame.offsetBy(dx: 0, dy: shift)
                return copy
            }
        }

        open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            guard let attrs = super.layoutAttributesForItem(at: indexPath) else { return nil }
            let shift = bottomAnchorShift
            guard shift > 0 else { return attrs }
            let copy = attrs.copy() as! UICollectionViewLayoutAttributes
            copy.frame = copy.frame.offsetBy(dx: 0, dy: shift)
            return copy
        }

        open override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
            guard let attrs = super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath) else { return nil }
            let shift = bottomAnchorShift
            guard shift > 0 else { return attrs }
            let copy = attrs.copy() as! UICollectionViewLayoutAttributes
            copy.frame = copy.frame.offsetBy(dx: 0, dy: shift)
            return copy
        }

        private func computeBottomAnchorShift() -> CGFloat {
            guard let collectionView = collectionView else { return 0 }
            let inset = collectionView.adjustedContentInset
            let availableHeight = collectionView.bounds.height - inset.top - inset.bottom
            let naturalHeight = super.collectionViewContentSize.height
            return max(0, availableHeight - naturalHeight)
        }
    }
}
