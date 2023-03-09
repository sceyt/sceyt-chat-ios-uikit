//
//  ChannelCollectionViewLayout.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

open class ChannelCollectionViewLayout: UICollectionViewLayout {
    
    public typealias Attributes = [[ChannelCollectionViewLayoutAttributes]]
    public let defaults: Defaults
    
    required public init(defaults: Defaults = .default) {
        self.defaults = defaults
        super.init()
    }
    
    required public init?(coder: NSCoder) {
        self.defaults = .default
        super.init(coder: coder)
    }
    
    public weak var delegate: ChannelCollectionViewLayoutDelegate?
    
    public var isInsertingItemsToTop = false
    public var scrollToPositionAfterInvalidationContext: ScrollToPosition = .none
    public private(set) var footerLayoutAttributes = [IndexPath: ChannelCollectionViewLayoutAttributes]()
    public private(set) var sectionLayoutAttributes = [ChannelCollectionViewLayoutAttributes]()
    public private(set) var currentLayoutAttributes = Attributes()
    public private(set) var prevLayoutAttributes = Attributes()
    public private(set) var deletedLayoutAttributes = Set<IndexPath>()
    
    private var hasInvalidateDataSourceCountsBeforePrepareUpdateItems = false
    private var hasPinnedFooter = false
    private var lastSizedElementMinY: CGFloat?
    private var lastSizedElementPreferredHeight: CGFloat?
    private var prevContentSizeHeight: CGFloat?
    private var contentOffsetBeforeUpdate: CGPoint?
    private var needsToScrollAtIndexPath = false
    private var cachedAttributesInRect: (CGRect, [ChannelCollectionViewLayoutAttributes])?
    
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
            var height = CGFloat(0)
            if let last = currentLayoutAttributes.last?.last {
                height = last.frame.maxY
            }
            let lastSectionHeight = sectionLayoutAttributes.last?.frame.maxY ?? 0
            size.height = max(height, lastSectionHeight)
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
//            needsToScrollAtIndexPath = !collectionView.indexPathsForVisibleItems.contains(indexPath)
//            invalidateLayout(with: context)
        } else {
            needsToScrollAtIndexPath = true
        }
    }
    
    private func updateContentOffsetIfInsertedToTop() {
        if let collectionView = collectionView,
            isInsertingItemsToTop == true {
            UIView.performWithoutAnimation {
                let newContentSizeHeight = self.collectionViewContentSize.height
                let contentOffsetY = collectionView.contentOffset.y + (newContentSizeHeight - collectionView.contentSize.height)
                let newOffset = CGPoint(x: collectionView.contentOffset.x, y: min(contentOffsetY, collectionView.contentSize.height))
                collectionView.contentOffset = newOffset
                
            }
        }
    }
    
    open override func prepare() {
        super.prepare()
        log("[ChannelCollectionViewLayout]", #function)
        guard let collectionView = collectionView
        else { return }
        defer {
            updateContentOffsetIfInsertedToTop()
        }
        guard currentLayoutAttributes.isEmpty
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
            offset += defaults.estimatedFooterHeight
            sectionLayoutAttributes.append(attribute)
            for item in 0 ..< numberOfItems {
                let indexPath = IndexPath(item: item, section: section)
                offset += interItemSpacing(before: indexPath)
                let attribute = ChannelCollectionViewLayoutAttributes(
                    forCellWith: indexPath)
                attribute.zIndex = defaults.cellZIndex
                attribute.frame = CGRect(
                    x: 0,
                    y: offset,
                    width: width,
                    height: defaults.estimatedCellHeight
                )
                currentLayoutAttributes.append(attribute)
                offset += defaults.estimatedCellHeight
            }
        }
        lastSizedElementMinY = nil
        lastSizedElementPreferredHeight = nil
        guard !currentLayoutAttributes.isEmpty else { return }
    }
    
    open override func prepare(
        forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]
    ) {
        log("[ChannelCollectionViewLayout]", #function)
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
        log("[ChannelCollectionViewLayout]", #function)
        guard !hasInvalidateDataSourceCountsBeforePrepareUpdateItems,
              let collectionView = collectionView else { return nil }
//        if let cachedAttributesInRect,
//           cachedAttributesInRect.0.contains(rect) {
//            var attributes = [ChannelCollectionViewLayoutAttributes]()
//            for attribute in cachedAttributesInRect.1 {
//                if rect.intersects(attribute.frame) {
//                    attribute.frame.size.width = collectionView.bounds.width
//                    attributes.append(attribute)
//                }
//            }
//            return attributes
//        }
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

        cachedAttributesInRect = (rect, attributes)
        return attributes
    }
    
    open override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        log("[ChannelCollectionViewLayout]", #function)
        guard !hasInvalidateDataSourceCountsBeforePrepareUpdateItems,
              currentLayoutAttributes.contains(indexPath)
        else { return nil }
        return currentLayoutAttributes[indexPath]
    }
    
    open override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        log("[ChannelCollectionViewLayout]", #function)
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
        log("[ChannelCollectionViewLayout]", #function)
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
        log("[ChannelCollectionViewLayout]", #function)
        guard currentLayoutAttributes.contains(itemIndexPath) else { return nil }
        return currentLayoutAttributes[itemIndexPath]
    }
    
    open override func finalLayoutAttributesForDisappearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        log("[ChannelCollectionViewLayout]", #function)
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
                attribute.alpha = 1
                return attribute
            }
        }
        if currentLayoutAttributes.contains(itemIndexPath) {
            return currentLayoutAttributes[itemIndexPath]
        }
        return super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
    }
    
    open override func finalLayoutAttributesForDisappearingSupplementaryElement(
        ofKind elementKind: String,
        at elementIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        log("[ChannelCollectionViewLayout]", #function)
        return super.finalLayoutAttributesForDisappearingSupplementaryElement(
            ofKind: elementKind,
            at: elementIndexPath
        )
    }
    
    open override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        log("[ChannelCollectionViewLayout]", #function)
        guard let collectionView = collectionView
        else { return false }
        
        let isLastVisible = sectionLayoutAttributes.last.map { newBounds.contains($0.frame.origin)} ?? false
        let isLastPinned = sectionLayoutAttributes.last.map { footerLayoutAttributes[$0.indexPath] != nil } ?? false
        
        let shouldInvalidateLayout = hasPinnedFooter ||
        (isLastVisible && !isLastPinned) ||
        collectionView.bounds.size != newBounds.size
        return shouldInvalidateLayout
    }
    
    open override func shouldInvalidateLayout(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> Bool {
        log("[ChannelCollectionViewLayout]", #function)
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
        log("[ChannelCollectionViewLayout] invalidateLayout")
    }
    
    open override func invalidationContext(
        forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes,
        withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutInvalidationContext {
        log("[ChannelCollectionViewLayout]", #function)
        defer {
            scrollToPositionAfterInvalidationContext(
                preferredAttributes: preferredAttributes,
                originalAttributes: originalAttributes
            )
        }
        let context = super.invalidationContext(
            forPreferredLayoutAttributes: preferredAttributes,
            withOriginalAttributes: originalAttributes
        )
        log("[ChannelCollectionViewLayout]", preferredAttributes.indexPath)
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
                        continue
                    }
                    for attribute in attributes {
                        attribute.frame.origin.y += shift
                    }
                }
            }
        case .supplementaryView:
            guard currentLayoutAttributes.indices.contains(indexPath.section)
            else { break }
            if preferredAttributes.representedElementKind == defaults.elementHeader {
                shift = sectionLayoutAttributes[indexPath.section].frame.maxY
                sectionLayoutAttributes[indexPath.section].frame.origin.y = preferredSectionPosition(for: indexPath.section)
                sectionLayoutAttributes[indexPath.section].frame.size.height = preferredAttributes.frame.height
                shift = sectionLayoutAttributes[indexPath.section].frame.maxY - shift
                if shift > 0, currentLayoutAttributes.indices.contains(indexPath.section) {
                    for section in indexPath.section ..< currentLayoutAttributes.count {
                        let attributes = currentLayoutAttributes[section]
                        if section != indexPath.section {
                            sectionLayoutAttributes[section].frame.origin.y += shift
                        }
                        for attribute in attributes {
                            attribute.frame.origin.y += shift
                        }
                    }
                }
            }
        case .decorationView:
            break
        @unknown default:
            break
        }
        
        let currentElementY = originalAttributes.frame.minY
        let isScrolling = collectionView.isDragging || collectionView.isDecelerating
        let isSizingElementAboveTopEdge = originalAttributes.frame.minY < collectionView.contentOffset.y

        if isScrolling && isSizingElementAboveTopEdge {
            let isSameRowAsLastSizedElement = lastSizedElementMinY == currentElementY
            if isSameRowAsLastSizedElement {
                let lastSizedElementPreferredHeight = self.lastSizedElementPreferredHeight ?? 0
                if preferredAttributes.size.height > lastSizedElementPreferredHeight {
                    context.contentOffsetAdjustment.y = preferredAttributes.size.height - lastSizedElementPreferredHeight
                }
            } else {
                context.contentOffsetAdjustment.y = preferredAttributes.size.height - originalAttributes.size.height
            }
        }
        
        lastSizedElementMinY = currentElementY
        lastSizedElementPreferredHeight = preferredAttributes.size.height
        return context
    }
    
    open override func invalidationContext(
        forBoundsChange newBounds: CGRect
    ) -> UICollectionViewLayoutInvalidationContext {
        log("[ChannelCollectionViewLayout]", #function)
        let context = super.invalidationContext(forBoundsChange: newBounds)
        guard let cv = collectionView else { return context }
        context.contentSizeAdjustment = CGSize(width: newBounds.width - cv.bounds.width,
                                               height: newBounds.height - cv.bounds.height)
        return context
    }
    
    open override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint
    ) -> CGPoint {
        log("[ChannelCollectionViewLayout]", #function)
        if let prevContentSizeHeight = prevContentSizeHeight,
           let contentOffsetBeforeUpdate = contentOffsetBeforeUpdate,
        isInsertingItemsToTop {
            let shift = collectionViewContentSize.height - prevContentSizeHeight
            return CGPoint(x: proposedContentOffset.x, y: contentOffsetBeforeUpdate.y + shift)
        }
        return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
    }
    
    
    open override func finalizeCollectionViewUpdates() {
        log("[ChannelCollectionViewLayout]", #function)
        contentOffsetBeforeUpdate = nil
        deletedLayoutAttributes.removeAll()
        super.finalizeCollectionViewUpdates()
        prevLayoutAttributes.removeAll()
    }
    
    open func clearCache() {
        currentLayoutAttributes.removeAll()
        sectionLayoutAttributes.removeAll()
        prevLayoutAttributes.removeAll()
        footerLayoutAttributes.removeAll()
    }
    
    public final func layoutAttributesWithId(_ id: UUID) -> ChannelCollectionViewLayoutAttributes? {
        for section in currentLayoutAttributes {
            for item in section {
                if item.id == id {
                    return item
                }
            }
        }
        return nil
    }
    
    public final func layoutAttributesInVisibleBounds(
        indexPaths: [IndexPath]? = nil
    ) -> [ChannelCollectionViewLayoutAttributes] {
        let rect = visibleBounds
        var attributes = [ChannelCollectionViewLayoutAttributes]()
        if let indexPaths {
            for indexPath in indexPaths {
                if currentLayoutAttributes.contains(indexPath),
                   rect.intersects(currentLayoutAttributes[indexPath].frame) {
                    attributes.append(currentLayoutAttributes[indexPath])
                }
            }
        } else {
            for section in 0 ..< currentLayoutAttributes.count {
                for row in 0 ..< currentLayoutAttributes[section].count {
                    let attribute = currentLayoutAttributes[section][row]
                    if rect.intersects(attribute.frame) {
                        attributes.append(attribute)
                    }
                }
            }
        }
        return attributes
    }
    
    open func scrollToPositionAfterInvalidationContext(
        preferredAttributes: UICollectionViewLayoutAttributes,
        originalAttributes: UICollectionViewLayoutAttributes
    ) {
        scrollToPosition()
    }
    
    private func scrollToPosition() {
        guard let collectionView = collectionView else { return }
        var newY: CGFloat?
        switch scrollToPositionAfterInvalidationContext {
        case .none:
            break
        case .end:
            guard !currentLayoutAttributes.isEmpty else { return }
            for index in (0 ..< currentLayoutAttributes.count).reversed() {
                if !currentLayoutAttributes[index].isEmpty {
                    newY = currentLayoutAttributes[index].last!.frame.maxY - collectionView.frame.height + collectionView.contentInset.bottom
                    break
                }
            }
        case let .indexPath(indexPath):
            if currentLayoutAttributes.contains(indexPath) {
                newY = currentLayoutAttributes[indexPath].frame.minY
            }
        }
        guard let newY,
              collectionView.contentOffset.y != newY
        else { return }
        UIView.performWithoutAnimation {
            collectionView
                .setContentOffset(
                    .init(
                        x: collectionView.contentOffset.x,
                        y: newY),
                    animated: false)
        }
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
                    return sectionLayoutAttributes[indexPath.section].frame.maxY + interItemSpacing(before: indexPath)
                }
                return 0
            }
            if sectionAttributes.indices.contains(indexPath.row) {
                return sectionAttributes[indexPath.row].frame.minY
            }
            return sectionAttributes.last!.frame.maxY + interItemSpacing(before: indexPath)
        }
        if currentLayoutAttributes.indices.contains(indexPath.section) {
            let sectionAttributes = currentLayoutAttributes[indexPath.section]
            if sectionAttributes.isEmpty {
                if sectionLayoutAttributes.indices.contains(indexPath.section) {
                    return sectionLayoutAttributes[indexPath.section].frame.maxY + interItemSpacing(before: indexPath)
                }
                if sectionLayoutAttributes.indices.contains(indexPath.section - 1) {
                    return  max(
                        (currentLayoutAttributes[indexPath.section - 1].last?.frame.maxY ?? 0)
                        + sectionLayoutAttributes[indexPath.section - 1].frame.height
                        + interItemSpacing(before: indexPath),
                        sectionLayoutAttributes[indexPath.section - 1].frame.maxY) + interItemSpacing(before: indexPath)
                }
                guard let prevSectionAttributesLast = currentLayoutAttributes.prefix(indexPath.section).last(where: { !$0.isEmpty})?.last
                else { return 0 }
                return prevSectionAttributesLast.frame.maxY + interItemSpacing(before: indexPath)
            }
            if sectionAttributes.indices.contains(indexPath.row) {
                return sectionAttributes[indexPath.row].frame.minY
            }
            return sectionAttributes.last!.frame.maxY + interItemSpacing(before: indexPath)
        }
        if let last = currentLayoutAttributes.last?.last {
            return last.frame.maxY
        } else {
            return 0
        }
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
            if let nextAttributes = currentLayoutAttributes.attributes(at: .init(item: 0, section: section))
                ?? currentLayoutAttributes.attributes(after: .init(item: 0, section: section)) {
                return sectionAttributes.last!.frame.maxY + interItemSpacing(before: nextAttributes.indexPath)
            }
            return sectionAttributes.last!.frame.maxY
            
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
    
    @discardableResult
    func insert(indexPaths: [IndexPath], preferredHeight: CGFloat? = nil)
    -> [ChannelCollectionViewLayoutAttributes] {
        var insertedAttributes = [ChannelCollectionViewLayoutAttributes]()
        let estimatedCellHeight = preferredHeight ?? defaults.estimatedCellHeight
        for indexPath in indexPaths.sorted() {
            deletedLayoutAttributes.remove(indexPath)
            let attribute = ChannelCollectionViewLayoutAttributes(forCellWith: indexPath)
            insertedAttributes.append(attribute)
            attribute.zIndex = defaults.cellZIndex
            let offset = preferredPosition(for: indexPath)
            attribute.frame = CGRect(x: 0, y: offset, width: collectionViewWidth, height: estimatedCellHeight)
            currentLayoutAttributes.insert(attribute)
            guard let nextAttributes = currentLayoutAttributes.attributes(after: indexPath)
            else { continue }
            let shift = estimatedCellHeight + interItemSpacing(before: nextAttributes.indexPath)
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
                    attributes.first!.frame.origin.y = sectionLayoutAttributes[section].frame.maxY + interItemSpacing(before: attributes.first!.indexPath)
                    for index in 1 ..< attributes.count {
                        attributes[index].frame.origin.y = attributes[index - 1].frame.maxY + interItemSpacing(before: attributes[index].indexPath)
                    }
                }
            }
            
        }
        return insertedAttributes
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
            let shift = defaults.estimatedFooterHeight
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
        for indexPath in indexPaths.sorted().reversed() {
            guard currentLayoutAttributes.contains(indexPath)
            else { continue }
            let attribute = currentLayoutAttributes.remove(at: indexPath)
            guard let currentAttributes = currentLayoutAttributes.attributes(at: indexPath)
            else { continue }
            let shift = attribute.frame.height + interItemSpacing(before: currentAttributes.indexPath)
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
                    attributes.first?.frame.origin.y = sectionLayoutAttributes[section - 1].frame.maxY + interItemSpacing(before: indexPath)
                    for index in 1 ..< attributes.count {
                        attributes[index].frame.origin.y = attributes[index - 1].frame.maxY + interItemSpacing(before: attributes[index].indexPath)
                    }
                }
            }
            deletedAttributes.append(attribute)
            deletedLayoutAttributes.insert(indexPath)
        }
        return deletedAttributes
    }
    
    func delete(sections: [Int]) {
        for section in sections.sorted().reversed()
        where sectionLayoutAttributes.indices.contains(section) {
            if sectionLayoutAttributes.count - 1 == section {
                sectionLayoutAttributes.removeLast()
                currentLayoutAttributes.removeLast()
            } else {
                let shift = sectionLayoutAttributes[section + 1].frame.minY - sectionLayoutAttributes[section].frame.minY
                sectionLayoutAttributes.remove(at: section)
                currentLayoutAttributes.remove(at: section)
                for move in section ..< sectionLayoutAttributes.count {
                    sectionLayoutAttributes[move].indexPath.section -= 1
                    sectionLayoutAttributes[move].frame.origin.y -= shift
                    for attributes in currentLayoutAttributes[section] {
                        attributes.frame.origin.y -= shift
                        attributes.indexPath.section = section
                    }
                }
            }
        }
    }
    
    func reload(indexPaths: [IndexPath]) {
        //not implemented
    }
    
    func reload(sections: [Int]) {
        //not implemented
    }
}

private extension CGRect {
    
    func preferredPinnedAttributesFrame(for rect: CGRect) -> CGRect {
        var preferredFrame = self
        preferredFrame.size.width = rect.width
        return preferredFrame
    }
}

private func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {return;
    debugPrint(items, separator: separator, terminator: terminator)
}
