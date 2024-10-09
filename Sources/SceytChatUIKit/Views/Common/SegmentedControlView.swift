//
//  SegmentedControlView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class SegmentedControlView: View,
    UIScrollViewDelegate,
    SegmentedControllerDelegate
{
    
    public lazy var appearance: SegmentedControl.Appearance = SegmentedControl.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    public private(set) var items: [SectionItem]

    open lazy var segmentController: SegmentedController & UIControl = SegmentedControl(items: items.map { $0.title })
        .withoutAutoresizingMask

    open lazy var scrollView = UIScrollView()
        .withoutAutoresizingMask

    open lazy var stackView = UIStackView()
        .withoutAutoresizingMask

    open var currentPage: Int {
        get {
            guard scrollView.frame.width > 0 else { return 0 }
            return Int((scrollView.contentOffset.x + (0.5 * scrollView.frame.size.width)) / scrollView.frame.width)
        }
        set {
            scrollView.contentOffset.x = scrollView.frame.width * Double(newValue)
        }
    }

    public required init(items: [SectionItem]) {
        self.items = items
        super.init(frame: .zero)
    }

    public required init?(coder: NSCoder) {
        items = []
        super.init(coder: coder)
    }

    public var selectedIndex: Int {
        get { segmentController.currentSegmentIndex }
        set { segmentController.currentSegmentIndex = newValue }
    }

    public var selectedItem: SectionItem {
        items[selectedIndex]
    }

    override open func setup() {
        super.setup()
        selectedIndex = 0
        segmentController.delegate = self

        scrollView.delegate = self
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = false
        scrollView.isDirectionalLockEnabled = true
        stackView.distribution = .equalSpacing
    }

    private var _isConfigured = false

    override open func setupLayout() {
        super.setupLayout()

        addSubview(segmentController)
        addSubview(scrollView)
        scrollView.addSubview(stackView)

        segmentController.pin(to: self, anchors: [.leading, .trailing, .top])
        segmentController.resize(anchors: [.height(49)])
        scrollView.topAnchor.pin(to: segmentController.bottomAnchor)
        scrollView.pin(to: self, anchors: [.leading, .trailing, .bottom])
        stackView.pin(to: scrollView)

        items.forEach {
            let v = $0.content.withoutAutoresizingMask
            stackView.addArrangedSubview(v)
            v.pin(to: scrollView, anchors: [.height, .width])
        }
        _isConfigured = true
    }

    override open func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = .clear
        scrollView.backgroundColor = .clear
        (segmentController as? SegmentedControl)?.parentAppearance = appearance
    }

    @objc
    open func didSelectSegment(at index: Int) {
        if items.indices.contains(index) {
            scrollView.setContentOffset(CGPoint(x: index * Int(scrollView.bounds.width), y: 0), animated: true)
        }
    }

    // MARK: UIScrollViewDelegate

    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard currentPage != selectedIndex else { return }
        selectedIndex = currentPage
    }

    public weak var parentScrollView: UIScrollView?
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollView.contentOffset.y = 0

        segmentController.currentPosition = (scrollView.contentOffset.x + (0.5 * scrollView.frame.width)) / scrollView.contentSize.width
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        parentScrollView?.isScrollEnabled = false
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
//        let targetIdx = Int((targetContentOffset.pointee.x + (0.5 * scrollView.frame.size.width)) / scrollView.frame.width)
//        let targetItem = items[targetIdx]
//        (targetItem.content as? UIScrollView)?.isScrollEnabled = true
//        if let contentScrollView = targetItem.content as? UIScrollView {
//            parentScrollView?.isScrollEnabled = contentScrollView.contentOffset.y == 0
//        } else {
//            parentScrollView?.isScrollEnabled = true
//        }
        parentScrollView?.isScrollEnabled = true
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
//        (selectedItem.content as? UIScrollView)?.isScrollEnabled = true
//        if let contentScrollView = selectedItem.content as? UIScrollView {
//            parentScrollView?.isScrollEnabled = contentScrollView.contentOffset.y == 0
//        } else {
//            parentScrollView?.isScrollEnabled = true
//        }
        parentScrollView?.isScrollEnabled = true
    }

    open func insert(item: SectionItem, at index: Int) {
        items.insert(item, at: index)
        guard _isConfigured else { return }
        let v = item.content.withoutAutoresizingMask
        stackView.insertArrangedSubview(v, at: index)
        v.pin(to: scrollView)
        v.pin(to: scrollView, anchors: [.height, .width])
        setNeedsLayout()
    }
}

public extension SegmentedControlView {
    struct SectionItem {
        public let content: UIView
        public let title: String
        
        public init(content: UIView, title: String) {
            self.content = content
            self.title = title
        }
    }
}
