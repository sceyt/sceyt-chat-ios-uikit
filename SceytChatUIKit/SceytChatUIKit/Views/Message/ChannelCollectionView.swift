//
//  ChannelCollectionView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
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
        register(MessageSectionSeparatorView.self, kind: .header)
    }
    open var channelCollectionViewLayout: ChannelCollectionViewLayout {
        guard let layout = collectionViewLayout as? ChannelCollectionViewLayout else {
            fatalError("Invalid ChatCollectionViewLayout type")
        }
        return layout
    }

    open override func reloadData() {
        channelCollectionViewLayout.clearCache()
        super.reloadData()
    }
    
    open func scrollToBottom(animated: Bool = true, duration: CGFloat = 0.22) {
        guard contentSize.height > bounds.height - contentInset.bottom - contentInset.top
        else { return }
        
        let contentOffsetYAtBottom = channelCollectionViewLayout.collectionViewContentSize.height - frame.height + adjustedContentInset.bottom
        guard contentOffsetYAtBottom > contentOffset.y
        else { return }
        
        if animated {
            UIView.animate(withDuration: duration) {[weak self] in
                guard let self else { return }
                self.setContentOffset(CGPoint(x: self.contentOffset.x, y: contentOffsetYAtBottom), animated: false)
            }
        } else {
            setContentOffset(CGPoint(x: contentOffset.x, y: contentOffsetYAtBottom), animated: false)
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
