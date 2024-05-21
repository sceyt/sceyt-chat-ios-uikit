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
    SegmentedControlerDelegate
{
    public private(set) var items: [SectionItem]

    open lazy var segmentController: SegmentedControler & UIControl = NativeSegmentedController(items: items.map { $0.title })
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

    weak var parentScrollView: UIScrollView?
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

@objc
public protocol SegmentedControlerDelegate: AnyObject {
    @objc
    func didSelectSegment(at index: Int)
}

@objc
public protocol SegmentedControler {
    @objc
    var currentSegmentIndex: Int { get set }

    @objc
    var currentPosition: Double { get set }

    @objc
    weak var delegate: SegmentedControlerDelegate? { get set }
    
    @objc
    var showCornerRadius: Bool { get set }
}

public extension SegmentedControler where Self: UIControl {}

open class NativeSegmentedController: UIControl, SegmentedControler {
    public var currentSegmentIndex: Int {
        get {
            segmentedControl.selectedSegmentIndex
        }
        set {
            segmentedControl.selectedSegmentIndex = newValue
        }
    }

    public var currentPosition: Double = 0 {
        didSet {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    public weak var delegate: SegmentedControlerDelegate?
    
    public var showCornerRadius: Bool {
        get {
            layer.cornerRadius != 0
        }
        set {
            layer.cornerRadius = newValue ? Layouts.cornerRadius : 0
        }
    }

    private let segmentedControl: UISegmentedControl

    private let line = {
        $0.layer.masksToBounds = true
        return $0
    }(UIView())

    private let bottomBorder = UIView().withoutAutoresizingMask

    private var _observer: NSKeyValueObservation?

    init(items: [Any]?) {
        segmentedControl = .init(items: items).withoutAutoresizingMask
        super.init(frame: .zero)

        setup()
        setupLayout()
        setupAppearance()
    }
    
    public required init?(coder: NSCoder) {
        segmentedControl = .init().withoutAutoresizingMask
        super.init(coder: coder)
    }
    
    func setup() {
        _observer = segmentedControl.observe(\.selectedSegmentIndex, options: [.new, .old]) { [weak self] _, _ in
            guard let self = self else { return }
            self.delegate?.didSelectSegment(at: self.segmentedControl.selectedSegmentIndex)
        }

        if segmentedControl.numberOfSegments > 0 {
            currentPosition = 1 / Double(segmentedControl.numberOfSegments) / 2
        }
    }

    func setupLayout() {
        addSubview(segmentedControl)
        addSubview(bottomBorder)
        addSubview(line)
        
        segmentedControl.pin(to: self)
        bottomBorder.pin(to: self, anchors: [.leading, .trailing, .bottom])
        bottomBorder.resize(anchors: [.height(Layouts.bottomSeparatorHeight)])
    }

    func setupAppearance() {
        backgroundColor = appearance.backgroundColor
        layer.cornerRadius = Layouts.cornerRadius
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.masksToBounds = true
        line.backgroundColor = .kitBlue
        bottomBorder.backgroundColor = .separator
        segmentedControl.setTitleTextAttributes([
            .font: appearance.font ?? Fonts.semiBold.withSize(16),
            .foregroundColor: appearance.selectedTextColor ?? .textBlack
        ], for: .selected)
        segmentedControl.setTitleTextAttributes([
            .font: appearance.font ?? Fonts.semiBold.withSize(16),
            .foregroundColor: appearance.textColor ?? .textGray
        ], for: .normal)

        segmentedControl.setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)
        segmentedControl.setDividerImage(UIImage(), forLeftSegmentState: [], rightSegmentState: [], barMetrics: .default)
    }
    
    private var lineWidth: CGFloat {
        let fontAttributes = [NSAttributedString.Key.font: appearance.font ?? Fonts.semiBold.withSize(16)]
        let max = Double(segmentedControl.numberOfSegments - 1)
        let idx = currentPosition * max
        let leftIdx = floor(currentPosition * max)
        let leftWidth = segmentedControl.titleForSegment(at: Int(leftIdx))?.size(withAttributes: fontAttributes).width ?? 0
        let rightIdx = ceil(currentPosition * max)
        let rightWidth = segmentedControl.titleForSegment(at: Int(rightIdx))?.size(withAttributes: fontAttributes).width ?? 0
        return min(floor(width / CGFloat(segmentedControl.numberOfSegments)), leftWidth + (idx - leftIdx) * (rightWidth - leftWidth) + Layouts.selectedIndicatorPadding)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        line.frame = .init(x: CGFloat(currentPosition) * width - line.width / 2, 
                           y: height - Layouts.selectedIndicatorHeight,
                           width: lineWidth,
                           height: Layouts.selectedIndicatorHeight)
        line.layer.cornerRadius = Layouts.selectedIndicatorHeight / 2
    }

    deinit {
        _observer = nil
    }
}

public extension NativeSegmentedController {
    enum Layouts {
        public static var cornerRadius: CGFloat = 10
        public static var selectedIndicatorHeight: CGFloat = 3
        public static var selectedIndicatorPadding: CGFloat = 4
        public static var bottomSeparatorHeight: CGFloat = 1
    }
}
