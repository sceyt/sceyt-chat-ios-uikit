//
//  ChannelCollectionViewLayout.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 6/4/22.
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

open class ChannelCollectionViewLayout: UICollectionViewLayout {
    
    public typealias Attributes = [[ChannelCollectionViewLayoutAttributes]]
    let defaults: Defaults
    
    required public init(defaults: Defaults = .default) {
        self.defaults = defaults
        super.init()
    }
    
    required public init?(coder: NSCoder) {
        self.defaults = .default
        super.init(coder: coder)
    }
    
    public var scrollToIndexPath: IndexPath? {
        willSet {
            guard let newValue else { return }
            scrollTo(indexPath: newValue)
        }
    }
    
    public private(set) var footerLayoutAttributes = [IndexPath: ChannelCollectionViewLayoutAttributes]()
    public private(set) var sectionLayoutAttributes = [ChannelCollectionViewLayoutAttributes]()
    public private(set) var currentLayoutAttributes = Attributes()
    public private(set) var prevLayoutAttributes = Attributes()
    public private(set) var deletedLayoutAttributes = Set<IndexPath>()
    
    private var scrollToIndexAfterInvalidationContext: IndexPath?
    private var hasInvalidateDataSourceCountsBeforePrepareUpdateItems = false
    private var hasPinnedFooter = false
    private var lastSizedElementMinY: CGFloat?
    private var lastSizedElementPreferredHeight: CGFloat?
    private var prevContentSizeHeight: CGFloat?
    private var contentOffsetBeforeUpdate: CGPoint?
    private var needsToScrollAtIndexPath = false
    
    fileprivate var collectionViewWidth: CGFloat {
        collectionView?.frame.width ?? 0
    }
    
    open override class var layoutAttributesClass: AnyClass {
        ChannelCollectionViewLayoutAttributes.self
    }
    
    open override var collectionViewContentSize: CGSize {
        var size = CGSize.zero
        guard let collectionView = collectionView
        else { return size }
        let contentInset = collectionView.adjustedContentInset
        
        // See https://openradar.appspot.com/radar?id=5025850143539200 for more details for `- 0.0001`.
        size.width = collectionView.bounds.width - contentInset.left - contentInset.right - 0.0001
        if collectionView.numberOfSections > 0 {
            let posCell = preferredPosition(for: .init(row: NSNotFound, section: NSNotFound))
            let posSupplementary = sectionLayoutAttributes.last?.frame.maxY ?? 0
            size.height = max(posCell, posSupplementary)
        } else {
            size.height = 0
        }
        return size
    }
    
    public var visibleBounds: CGRect {
        guard let collectionView = collectionView
        else { return .zero }
        let adjustedContentInset = collectionView.adjustedContentInset
        return CGRect(x: adjustedContentInset.left,
                      y: collectionView.contentOffset.y + adjustedContentInset.top,
                      width: collectionView.bounds.width - adjustedContentInset.left - adjustedContentInset.right,
                      height: collectionView.bounds.height - adjustedContentInset.top - adjustedContentInset.bottom)
    }
    
    private func scrollTo(indexPath: IndexPath) {
        guard let collectionView = collectionView
        else { return }
        
        if currentLayoutAttributes.contains(indexPath) {
            let attributes = currentLayoutAttributes[indexPath]
            let itemMidY = attributes.frame.maxY
//            UIView.performWithoutAnimation {
            collectionView.contentOffset.y = max(0, itemMidY) + collectionView.contentInset.bottom
//            }
            
//            let context = UICollectionViewLayoutInvalidationContext()
//            context.contentOffsetAdjustment.y = 0
            needsToScrollAtIndexPath = !collectionView.indexPathsForVisibleItems.contains(indexPath)
//            invalidateLayout(with: context)
        } else {
            needsToScrollAtIndexPath = true
        }
    }
    
    open override func prepare() {
        debugPrint("[scrollToIndexPath]", #function)
        guard let collectionView = collectionView,
              currentLayoutAttributes.isEmpty
        else { return }
        var offset = CGFloat(0)
        let width = collectionView.bounds.width
        for section in 0 ..< collectionView.numberOfSections {
            let numberOfItems = collectionView.numberOfItems(inSection: section)
            guard numberOfItems > 0 else { continue }
            let attribute = ChannelCollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: defaults.elementHeader,
                with: IndexPath(item: 1, section: section)
            )
            attribute.zIndex = defaults.footerZIndex
            attribute.frame = .init(
                x: 0,
                y: offset,
                width: width,
                height: defaults.estimatedFooterHeight
            )
            offset += defaults.estimatedFooterHeight + defaults.estimatedInterItemSpacing
            sectionLayoutAttributes.append(attribute)
            for item in 0 ..< numberOfItems {
                let attribute = ChannelCollectionViewLayoutAttributes(
                    forCellWith: IndexPath(item: item, section: section))
                attribute.zIndex = defaults.cellZIndex
                attribute.frame = CGRect(
                    x: 0,
                    y: offset,
                    width: width,
                    height: defaults.estimatedCellHeight
                )
                offset += defaults.estimatedCellHeight + defaults.estimatedInterItemSpacing
                currentLayoutAttributes.append(attribute)
            }
        }
        lastSizedElementMinY = nil
        lastSizedElementPreferredHeight = nil
        guard !currentLayoutAttributes.isEmpty else { return }
    }
    
    open override func prepare(
        forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]
    ) {
        debugPrint("[scrollToIndexPath]", #function)
        prevLayoutAttributes = currentLayoutAttributes
        var insertIndexPaths = [IndexPath]()
        var insertSections = [Int]()
        var deleteIndexPaths = [IndexPath]()
        var deleteSections = [Int]()
        var reloadIndexPaths = [IndexPath]()
        var reloadSections = [Int]()
        
        updateItems.forEach { item in
            let indexPathBeforeUpdate = item.indexPathBeforeUpdate
            let indexPathAfterUpdate = item.indexPathAfterUpdate
            switch item.updateAction {
            case .insert:
                guard let indexPath = indexPathAfterUpdate
                else {
                    assertionFailure("UICollectionViewUpdateItem.indexPathAfterUpdate is nil for a .insert updateAction")
                    return
                }
                if indexPath.item == NSNotFound {
                    insertSections.append(indexPath.section)
                } else {
                    insertIndexPaths.append(indexPath)
                }
            case .delete:
                guard let indexPath = indexPathBeforeUpdate
                else {
                    assertionFailure("UICollectionViewUpdateItem.indexPathBeforeUpdate is nil for a .delete updateAction")
                    return
                }
                if indexPath.item == NSNotFound {
                    deleteSections.append(indexPath.section)
                } else {
                    deleteIndexPaths.append(indexPath)
                }
            case .reload:
                guard let indexPath = indexPathBeforeUpdate
                else {
                    assertionFailure("UICollectionViewUpdateItem.indexPathBeforeUpdate is nil for a .reload updateAction")
                    return
                }
                if indexPath.item == NSNotFound {
                    reloadSections.append(indexPath.section)
                } else {
                    reloadIndexPaths.append(indexPath)
                }
            case .move:
                guard let fromIndexPath = indexPathBeforeUpdate,
                        let toIndexPath = indexPathAfterUpdate
                else {
                    assertionFailure("UICollectionViewUpdateItem.indexPathBeforeUpdate/indexPathAfterUpdate is nil for a .move updateAction")
                    return
                }
                if fromIndexPath.item == NSNotFound && toIndexPath.item == NSNotFound {
                    deleteSections.append(fromIndexPath.section)
                    insertSections.append(toIndexPath.section)
                } else {
                    deleteIndexPaths.append(fromIndexPath)
                    insertIndexPaths.append(toIndexPath)
                }
            default:
                break
            }
        }
        reload(indexPaths: reloadIndexPaths.sorted())
        reload(sections: reloadSections.sorted())
        delete(indexPaths: deleteIndexPaths.sorted())
        delete(sections: deleteSections.sorted())
        insert(sections: insertSections.sorted())
        insert(indexPaths: insertIndexPaths.sorted())
        
        hasInvalidateDataSourceCountsBeforePrepareUpdateItems = false
        super.prepare(forCollectionViewUpdates: updateItems)
    }
    
    open override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        debugPrint("[scrollToIndexPath]", #function)
        guard !hasInvalidateDataSourceCountsBeforePrepareUpdateItems,
              let collectionView = collectionView else { return nil }
        var attributes = [ChannelCollectionViewLayoutAttributes]()
        for section in 0 ..< currentLayoutAttributes.count {
            for row in 0 ..< currentLayoutAttributes[section].count {
                let attribute = currentLayoutAttributes[section][row]
                if rect.intersects(attribute.frame) {
                    attribute.frame.size.width = collectionView.bounds.width
                    attributes.append(attribute)
                }
            }
        }
        let boundsMaxY = currentVisibleBounds.minY
        var lowerIndex: Int?
        var upperIndex: Int?
        var lowerRange = CGFloat.greatestFiniteMagnitude
        var upperRange = CGFloat.greatestFiniteMagnitude
        
        for (index, attribute) in sectionLayoutAttributes.enumerated() {
            if rect.intersects(attribute.frame) {
                attribute.frame.size.width = collectionView.bounds.width
                attributes.append(attribute)
            }
            
            attribute.alpha = 1
            let lower = boundsMaxY - attribute.frame.maxY
            if lower >= 0, lower <= lowerRange {
                lowerRange = lower
                lowerIndex = index
            } else if lower < 0, currentVisibleBounds.intersects(attribute.frame) {
                lowerIndex = index
                upperIndex = nil
                continue
            }
            let upper = attribute.frame.minY - boundsMaxY
            if upper >= 0, upper <= upperRange {
                upperRange = upper
                upperIndex = index
            }
        }
        guard defaults.pinFooter
        else { return attributes }
        
        func zIndex( _ section: Int) -> Int {
            switch defaults.pinnedFooterZIndex {
            case .static(let index):
                return index
            case .dynamicNextToLatItemInRow:
                return collectionView.numberOfItems(inSection: section) + 1
            }
        }
        
        hasPinnedFooter = false
        footerLayoutAttributes.removeAll(keepingCapacity: true)
        switch (lowerIndex, upperIndex) {
        case (.none, .none):
            footerLayoutAttributes.removeAll()
        case let (.none, .some(upper)):
            var sectionAttribute = sectionLayoutAttributes[upper]
            var frame = sectionAttribute.frame
                .preferredPinnedAttributesFrame(for: rect)
            frame.origin.y = boundsMaxY - sectionAttribute.frame.height
            if upper > 0 {
                let lowerAttributes = sectionLayoutAttributes[upper - 1]
                if frame.intersects(lowerAttributes.frame) {
                    sectionAttribute = lowerAttributes
                }
            }
            sectionAttribute.alpha = 0
            let footerAttribute = ChannelCollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: defaults.elementHeader,
                with: .init(row: 2, section: sectionAttribute.indexPath.section)
            )
            footerAttribute.frame = frame
            footerAttribute.zIndex = zIndex(sectionAttribute.indexPath.section)
            attributes.append(footerAttribute)
            footerLayoutAttributes[footerAttribute.indexPath] = footerAttribute
            hasPinnedFooter = true
        case let (.some(lower), .some(upper)):
            let lowerAttribute = sectionLayoutAttributes[lower]
            let upperAttribute = sectionLayoutAttributes[upper]
            let lowerFrame = lowerAttribute.frame
                .preferredPinnedAttributesFrame(for: rect)
            var preferredUpperFrame = CGRect(
                x: upperAttribute.frame.minX,
                y: boundsMaxY - upperAttribute.frame.height,
                width: upperAttribute.frame.width,
                height: upperAttribute.frame.height)
                .preferredPinnedAttributesFrame(for: rect)
            if lowerFrame.maxY > preferredUpperFrame.minY {
                preferredUpperFrame.origin.y = lowerFrame.maxY
            }
            upperAttribute.alpha = 0
            let footerAttribute = ChannelCollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: defaults.elementHeader,
                with: .init(row: 2, section: upperAttribute.indexPath.section)
            )
            footerAttribute.frame = preferredUpperFrame
            footerAttribute.zIndex = zIndex(upperAttribute.indexPath.section)
            attributes.append(footerAttribute)
            footerLayoutAttributes[footerAttribute.indexPath] = footerAttribute
            hasPinnedFooter = true
        case let (.some(lower), .none):
            let sectionAttribute = sectionLayoutAttributes[lower]
            var frame = sectionAttribute.frame
                .preferredPinnedAttributesFrame(for: rect)
            frame.origin.y = boundsMaxY - sectionAttribute.frame.height
            guard frame.contains(sectionAttribute.frame.origin)
            else { break }
            sectionAttribute.alpha = 0
            let footerAttribute = ChannelCollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: defaults.elementHeader,
                with: .init(row: 2, section: sectionAttribute.indexPath.section)
            )
            footerAttribute.frame = frame
            footerAttribute.zIndex = zIndex(sectionAttribute.indexPath.section)
            attributes.append(footerAttribute)
            footerLayoutAttributes[footerAttribute.indexPath] = footerAttribute
            hasPinnedFooter = true
        }
        return attributes
    }
    
    open override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        debugPrint("[scrollToIndexPath]", #function)
        guard !hasInvalidateDataSourceCountsBeforePrepareUpdateItems,
              currentLayoutAttributes.contains(indexPath)
        else { return nil }
        return currentLayoutAttributes[indexPath]
    }
    
    open override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        debugPrint("[scrollToIndexPath]", #function)
        guard !hasInvalidateDataSourceCountsBeforePrepareUpdateItems,
              defaults.elementHeader == elementKind
        else { return nil }
        
        if footerLayoutAttributes[indexPath] != nil {
            return footerLayoutAttributes[indexPath]
        }
        if sectionLayoutAttributes.indices.contains(indexPath.section) {
            return sectionLayoutAttributes[indexPath.section]
        }
        return nil
    }
    
    open override func initialLayoutAttributesForAppearingSupplementaryElement(
        ofKind elementKind: String,
        at elementIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        debugPrint("[scrollToIndexPath]", #function)
        guard defaults.elementHeader == elementKind
        else { return nil }
        if footerLayoutAttributes[elementIndexPath] != nil {
            return footerLayoutAttributes[elementIndexPath]
        }
        if sectionLayoutAttributes.indices.contains(elementIndexPath.section) {
            return sectionLayoutAttributes[elementIndexPath.section]
        }
        return nil
    }
    
    open override func initialLayoutAttributesForAppearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        debugPrint("[scrollToIndexPath]", #function)
        guard currentLayoutAttributes.contains(itemIndexPath) else { return nil }
        return currentLayoutAttributes[itemIndexPath]
    }
    
    open override func finalLayoutAttributesForDisappearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        debugPrint("[scrollToIndexPath]", #function)
        if prevLayoutAttributes.contains(itemIndexPath) {
            if deletedLayoutAttributes.contains(itemIndexPath) {
                let attributes = prevLayoutAttributes[itemIndexPath]
                attributes.alpha = 0
                return attributes
            }
            let prevId = prevLayoutAttributes[itemIndexPath].id
            if let attribute = currentLayoutAttributes
                .attributes(id: prevId)?.copy()
                as? UICollectionViewLayoutAttributes {
                attribute.alpha = 0
                return attribute
            }
        }
        if currentLayoutAttributes.contains(itemIndexPath) {
            let attributes = currentLayoutAttributes[itemIndexPath].copy() as? UICollectionViewLayoutAttributes
            attributes?.alpha = 0
            return attributes
        }
        return super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
    }
    
    open override func finalLayoutAttributesForDisappearingSupplementaryElement(
        ofKind elementKind: String,
        at elementIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        debugPrint("[scrollToIndexPath]", #function)
        return super.finalLayoutAttributesForDisappearingSupplementaryElement(
            ofKind: elementKind,
            at: elementIndexPath
        )
    }
    
    open override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        guard let collectionView = collectionView
        else { return false }
        
        let isLastVisible = sectionLayoutAttributes.last.map { newBounds.contains($0.frame.origin)} ?? false
        let isLastPinned = sectionLayoutAttributes.last.map { footerLayoutAttributes[$0.indexPath] != nil } ?? false
        
        return hasPinnedFooter ||
        (isLastVisible && !isLastPinned) ||
        collectionView.bounds.size != newBounds.size
    }
    
    open override func shouldInvalidateLayout(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> Bool {
        debugPrint("[scrollToIndexPath]", #function)
        guard !preferredAttributes.indexPath.isEmpty
        else {
            return super.shouldInvalidateLayout(forPreferredLayoutAttributes: preferredAttributes,
                                                withOriginalAttributes: originalAttributes)
        }
        let isEqual = preferredAttributes.frame.size == originalAttributes.frame.size
        switch preferredAttributes.representedElementCategory {
        case .cell:
            return !isEqual
        case .supplementaryView:
//            if preferredAttributes.representedElementKind == defaults.elementFooter {
//                return footerLayoutAttributes[preferredAttributes.indexPath] == nil
//            }
            return true
        case .decorationView:
            break
        @unknown default:
            break
        }
        return false
    }
    
    open override func invalidateLayout(
        with context: UICollectionViewLayoutInvalidationContext
    ) {
        hasInvalidateDataSourceCountsBeforePrepareUpdateItems = context.invalidateDataSourceCounts && !context.invalidateEverything
        prevContentSizeHeight = collectionViewContentSize.height
        contentOffsetBeforeUpdate = collectionView?.contentOffset
        super.invalidateLayout(with: context)
        debugPrint("[scrollToIndexPath] invalidateLayout")
    }
    
    open override func invalidationContext(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutInvalidationContext {
        debugPrint("[scrollToIndexPath]", #function)
//        defer {
//            if let indexPath = scrollToIndexAfterInvalidationContext,
//               currentLayoutAttributes.contains(indexPath),
//               currentLayoutAttributes.last?.indexPath.item == preferredAttributes.indexPath.item {
//                scrollToIndexAfterInvalidationContext = nil
//                UIView.performWithoutAnimation {
//                    if let collectionView = collectionView {
//                        let delta: CGFloat = indexPath == currentLayoutAttributes.last?.indexPath ? 1 : 0.5
//                        collectionView.contentOffset.y =
//                        currentLayoutAttributes[indexPath].frame.maxY -
//                        delta * collectionView.bounds.height +
//                        collectionView.contentInset.top
//                    }
//                }
//            }
//        }
        let context = super.invalidationContext(
            forPreferredLayoutAttributes: preferredAttributes,
            withOriginalAttributes: originalAttributes
        )
        debugPrint("[scrollToIndexPath]", scrollToIndexPath, preferredAttributes.indexPath)
        guard let collectionView = collectionView else { return context }
        let indexPath = originalAttributes.indexPath
        var shift = CGFloat(0)
        switch preferredAttributes.representedElementCategory {
        case .cell:
            shift = preferredAttributes.frame.height - currentLayoutAttributes[indexPath].frame.height
            currentLayoutAttributes[indexPath].frame.size.height = preferredAttributes.frame.height
            
            for attribute in currentLayoutAttributes[indexPath.section].suffix(from: indexPath.row + 1) {
                attribute.frame.origin.y += shift
                
            }
            if currentLayoutAttributes.indices.contains(indexPath.section + 1) {
                for section in indexPath.section + 1 ..< currentLayoutAttributes.count {
                    sectionLayoutAttributes[section]
                        .frame.origin.y += shift
                    let attributes = currentLayoutAttributes[section]
                    if attributes.isEmpty {
//                        sectionLayoutAttributes[section]
//                            .frame.origin.y = preferredPosition(for: .init(row: 0, section: section))
                        continue
                    }
                    for attribute in attributes {
                        attribute.frame.origin.y += shift
                    }
//                    sectionLayoutAttributes[section]
//                        .frame.origin.y = attributes.last!.frame.maxY + defaults.estimatedInterItemSpacing
                }
            }
//            context.contentOffsetAdjustment.y = -shift
//            context.invalidateItems(at: [preferredAttributes.indexPath])
        case .supplementaryView:
            guard currentLayoutAttributes.indices.contains(indexPath.section)
            else { break }
            if preferredAttributes.representedElementKind == defaults.elementHeader {
                sectionLayoutAttributes[indexPath.section].frame.origin.y = preferredSectionPosition(for: indexPath.section)
                sectionLayoutAttributes[indexPath.section].frame.size.height = preferredAttributes.frame.height
                shift = preferredAttributes.frame.height - sectionLayoutAttributes[indexPath.section].frame.height
                if currentLayoutAttributes.indices.contains(indexPath.section) {
                    for section in indexPath.section ..< currentLayoutAttributes.count {
                        let attributes = currentLayoutAttributes[section]
                        sectionLayoutAttributes[section]
                            .frame.origin.y = preferredSectionPosition(for: section)
                        for attribute in attributes {
                            attribute.frame.origin.y += shift
                        }
                    }
                }
            }
//            context.contentOffsetAdjustment.y = -shift
//            context.invalidateSupplementaryElements(ofKind: UICollectionView.elementKindSectionFooter, at: [preferredAttributes.indexPath])
        case .decorationView:
            break
        @unknown default:
            break
        }
//        let isScrolling = collectionView.isDragging || collectionView.isDecelerating
//        let heightDifference = preferredAttributes.frame.height - originalAttributes.size.height
//        let isAboveBottomEdge = originalAttributes.frame.minY.rounded() <= visibleBounds.maxY.rounded()
//        let maxHeight = sectionLayoutAttributes.last?.frame.maxY ?? 0
//        if heightDifference != 0,
//           (maxHeight + heightDifference > visibleBounds.height.rounded()) || isScrolling,
//           isAboveBottomEdge {
//            debugPrint("[fixscroll] 1", heightDifference)
//            context.contentOffsetAdjustment.y += heightDifference
//        }
       
        debugPrint("[fixscroll] 1", preferredAttributes.indexPath, originalAttributes.indexPath)
        debugPrint("[fixscroll] 1.1", lastSizedElementMinY, lastSizedElementPreferredHeight)
        let currentElementY = originalAttributes.frame.minY

        let isScrolling = collectionView.isDragging || collectionView.isDecelerating
        let isSizingElementAboveTopEdge = originalAttributes.frame.minY < collectionView.contentOffset.y
        debugPrint("[fixscroll] 2", isScrolling, isSizingElementAboveTopEdge)
        if isScrolling && !isSizingElementAboveTopEdge {
            let isSameRowAsLastSizedElement = lastSizedElementMinY == currentElementY
            debugPrint("[fixscroll] 3", isSameRowAsLastSizedElement)
            if isSameRowAsLastSizedElement {
                let lastSizedElementPreferredHeight = self.lastSizedElementPreferredHeight ?? 0
                debugPrint("[fixscroll] 4", preferredAttributes.size.height, lastSizedElementPreferredHeight)
                if preferredAttributes.size.height > lastSizedElementPreferredHeight {
                    context.contentOffsetAdjustment.y += preferredAttributes.size.height - lastSizedElementPreferredHeight
                }
            } else {
                debugPrint("[fixscroll] 4", preferredAttributes.size.height, originalAttributes.size.height)
                context.contentOffsetAdjustment.y += preferredAttributes.size.height - originalAttributes.size.height
            }
        } else {
//            debugPrint("[fixscroll] 5", context.contentOffsetAdjustment.y, shift)
//            context.contentOffsetAdjustment.y = -shift
        }
        lastSizedElementMinY = currentElementY
        lastSizedElementPreferredHeight = preferredAttributes.size.height
        return context
    }
    
    open override func invalidationContext(
        forBoundsChange newBounds: CGRect
    ) -> UICollectionViewLayoutInvalidationContext {
        debugPrint("[scrollToIndexPath]", #function)
        let context = super.invalidationContext(forBoundsChange: newBounds)
        guard let cv = collectionView else { return context }
        context.contentSizeAdjustment = CGSize(width: newBounds.width - cv.bounds.width,
                                               height: newBounds.height - cv.bounds.height)
        return context
    }
    
//    open override func targetContentOffset(
//        forProposedContentOffset proposedContentOffset: CGPoint
//    ) -> CGPoint {
//        debugPrint("[scrollToIndexPath]", #function)
////        if let prevContentSizeHeight = prevContentSizeHeight,
////           let contentOffsetBeforeUpdate = contentOffsetBeforeUpdate {
////            let shift = collectionViewContentSize.height - prevContentSizeHeight
////            debugPrint("[loadm] targetContentOffset ", shift, prevContentSizeHeight, collectionViewContentSize.height, contentOffsetBeforeUpdate)
////            return CGPoint(x: proposedContentOffset.x, y: contentOffsetBeforeUpdate.y + shift)
////        }
//        if let offset = contentOffsetBeforeUpdate?.y {
//            debugPrint("[scrollToIndexPath] targetContentOffset, check", collectionViewContentSize.height - offset, proposedContentOffset.y)
//            return CGPoint(x: 0, y: proposedContentOffset.y - offset)
//        }
//        debugPrint("[scrollToIndexPath] targetContentOffset, check", proposedContentOffset.y)
//        return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
//    }
    
    
    open override func finalizeCollectionViewUpdates() {
        debugPrint("[scrollToIndexPath]", #function)
        contentOffsetBeforeUpdate = nil
        deletedLayoutAttributes.removeAll()
        super.finalizeCollectionViewUpdates()
        prevLayoutAttributes.removeAll()
        
        if needsToScrollAtIndexPath, let scrollToIndexPath {
            needsToScrollAtIndexPath = false
            scrollTo(indexPath: scrollToIndexPath)
        }
        if let collectionView = collectionView,
           let maxY = sectionLayoutAttributes.last?.frame.maxY {
            let compensatingOffset: CGFloat
            compensatingOffset = maxY - collectionView.contentOffset.y
            
            let context = UICollectionViewLayoutInvalidationContext()
//            context.contentOffsetAdjustment.y = compensatingOffset
            debugPrint("[fixscroll] compensatingOffset", compensatingOffset)
            invalidateLayout(with: context)
        }
    }
    
    open func clearCache() {
        currentLayoutAttributes.removeAll()
        sectionLayoutAttributes.removeAll()
        prevLayoutAttributes.removeAll()
        footerLayoutAttributes.removeAll()
    }
    
    private func preferredPosition(
        for indexPath: IndexPath
    ) -> CGFloat {
        guard !currentLayoutAttributes.isEmpty
        else { return 0 }
        
        if indexPath.section == 0 {
            let sectionAttributes = currentLayoutAttributes[0]
            if sectionAttributes.isEmpty {
                if sectionLayoutAttributes.indices.contains(indexPath.section) {
                    return sectionLayoutAttributes[indexPath.section].frame.maxY + defaults.estimatedInterItemSpacing
                }
                return 0
            }
            if sectionAttributes.indices.contains(indexPath.row) {
                return sectionAttributes[indexPath.row].frame.minY
            }
            return sectionAttributes.last!.frame.maxY + defaults.estimatedInterItemSpacing
        }
        if currentLayoutAttributes.indices.contains(indexPath.section) {
            let sectionAttributes = currentLayoutAttributes[indexPath.section]
            if sectionAttributes.isEmpty {
                if sectionLayoutAttributes.indices.contains(indexPath.section - 1) {
                    return  max(
                        (currentLayoutAttributes[indexPath.section - 1].last?.frame.maxY ?? 0)
                        + sectionLayoutAttributes[indexPath.section - 1].frame.height
                        + defaults.estimatedInterItemSpacing,
                        sectionLayoutAttributes[indexPath.section - 1].frame.maxY) + defaults.estimatedInterItemSpacing
                }
                guard let prevSectionAttributesLast = currentLayoutAttributes.prefix(indexPath.section).last(where: { !$0.isEmpty})?.last
                else { return 0 }
                return prevSectionAttributesLast.frame.maxY + defaults.estimatedInterItemSpacing
            }
            if sectionAttributes.indices.contains(indexPath.row) {
                return sectionAttributes[indexPath.row].frame.minY
            }
            return sectionAttributes.last!.frame.maxY + defaults.estimatedInterItemSpacing
        }
        return (currentLayoutAttributes.last?.last?.frame.maxY ?? 0) + defaults.estimatedInterItemSpacing
    }
    
    private func preferredSectionPosition(
        for section: Int
    ) -> CGFloat {
        guard !currentLayoutAttributes.isEmpty
        else { return 0 }
        
        if section == 0 {
            return 0
        }
        if currentLayoutAttributes.indices.contains(section - 1) {
            let sectionAttributes = currentLayoutAttributes[section - 1]
            if sectionAttributes.isEmpty {
                return preferredSectionPosition(for: section - 1)
            }
            return sectionAttributes.last!.frame.maxY + defaults.estimatedInterItemSpacing
        }
        return preferredSectionPosition(for: section - 1)
    }
    
    private var currentVisibleBounds: CGRect {
        guard let collectionView = collectionView
        else { return .zero }
        let contentInset = collectionView.adjustedContentInset
        let bounds = collectionView.bounds
        return CGRect(
            x: bounds.minX + contentInset.left,
            y: bounds.minY + contentInset.top,
            width: bounds.width - contentInset.left - contentInset.right,
            height: bounds.height - contentInset.top - contentInset.bottom)
    }
}

private extension ChannelCollectionViewLayout {
    
    func insert(indexPaths: [IndexPath], preferredHeight: CGFloat? = nil) {
        let estimatedCellHeight = preferredHeight ?? defaults.estimatedCellHeight
        for indexPath in indexPaths.sorted() {
            deletedLayoutAttributes.remove(indexPath)
            let attribute = ChannelCollectionViewLayoutAttributes(forCellWith: indexPath)
            attribute.zIndex = defaults.cellZIndex
            let offset = preferredPosition(for: indexPath)
            attribute.frame = CGRect(x: 0, y: offset, width: collectionViewWidth, height: estimatedCellHeight)
            currentLayoutAttributes.insert(attribute)
            let shift = estimatedCellHeight + defaults.estimatedInterItemSpacing
            for attribute in currentLayoutAttributes[indexPath.section].suffix(from: indexPath.row + 1) {
                attribute.frame.origin.y += shift
            }
            
            if currentLayoutAttributes.indices.contains(indexPath.section + 1) {
                for section in indexPath.section + 1 ..< currentLayoutAttributes.count {
                    sectionLayoutAttributes[section].frame.origin.y = preferredSectionPosition(for: section)
                    let attributes = currentLayoutAttributes[section]
                    if attributes.isEmpty {
                        continue
                    }
                    attributes.first?.frame.origin.y = sectionLayoutAttributes[section].frame.maxY + defaults.estimatedInterItemSpacing
                    for index in 1 ..< attributes.count {
                        attributes[index].frame.origin.y = attributes[index - 1].frame.maxY + defaults.estimatedInterItemSpacing
                    }
                }
            }
            
        }
    }
    
    func insert(sections: [Int]) {
        for section in sections.sorted() {
            let attribute = ChannelCollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: defaults.elementHeader,
                with: IndexPath(item: 1, section: section))
            attribute.frame = .init(x: 0, y: preferredSectionPosition(for: section), width: collectionViewWidth, height: defaults.estimatedFooterHeight)
            attribute.zIndex = defaults.footerZIndex
            sectionLayoutAttributes.insert(attribute, at: section)
            currentLayoutAttributes.insert(section: section)
            let shift = defaults.estimatedFooterHeight + defaults.estimatedInterItemSpacing
            for move in section + 1 ..< sectionLayoutAttributes.count {
                sectionLayoutAttributes[move].frame.origin.y += shift
                sectionLayoutAttributes[move].indexPath.section += 1
            }
        }
    }
    
    @discardableResult
    func delete(indexPaths: [IndexPath])
    -> [ChannelCollectionViewLayoutAttributes] {
        var deletedAttributes = [ChannelCollectionViewLayoutAttributes]()
        for indexPath in indexPaths {
            guard currentLayoutAttributes.contains(indexPath)
            else { continue }
            let attribute = currentLayoutAttributes.remove(at: indexPath)
            
            let shift = attribute.frame.height + defaults.estimatedInterItemSpacing
            for attribute in currentLayoutAttributes[indexPath.section].suffix(from: indexPath.row) {
                attribute.frame.origin.y -= shift
            }
            
            if currentLayoutAttributes.indices.contains(indexPath.section + 1) {
                for section in indexPath.section + 1 ..< currentLayoutAttributes.count {
                    sectionLayoutAttributes[section].frame.origin.y = preferredSectionPosition(for: section)
                    let attributes = currentLayoutAttributes[section]
                    if attributes.isEmpty {
                        continue
                    }
                    attributes.first?.frame.origin.y = sectionLayoutAttributes[section - 1].frame.maxY + defaults.estimatedInterItemSpacing
                    for index in 1 ..< attributes.count {
                        attributes[index].frame.origin.y = attributes[index - 1].frame.maxY + defaults.estimatedInterItemSpacing
                    }
                }
            }
            deletedAttributes.append(attribute)
            deletedLayoutAttributes.insert(indexPath)
        }
        return deletedAttributes
    }
    
    func delete(sections: [Int]) {
        for section in sections.sorted().reversed() {
            sectionLayoutAttributes.remove(at: section)
            for move in section ..< sectionLayoutAttributes.count {
                sectionLayoutAttributes[move].indexPath.section -= 1
            }
        }
    }
    
    func reload(indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            debugPrint("reload(indexPaths", indexPath)
            let height = delete(indexPaths: [indexPath]).last?.frame.height
            insert(indexPaths: [indexPath], preferredHeight: height)
        }
    }
    
    func reload(sections: [Int]) {
        //not implemented
    }
}

func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    debugPrint(items, separator: separator, terminator: terminator)
}

private extension CGRect {
    
    func preferredPinnedAttributesFrame(for rect: CGRect) -> CGRect {
        var preferredFrame = self
        preferredFrame.size.width = rect.width
        return preferredFrame
    }
}
