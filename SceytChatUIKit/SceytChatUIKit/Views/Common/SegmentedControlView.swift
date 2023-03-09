//
//  SegmentedControlView.swift
//  SceytChatUIKit
//

import UIKit

open class SegmentedControlView: View,
    UIScrollViewDelegate,
    SegmentedControlerDelegate
{
    public private(set) var items: [SectionItem]

    open lazy var segmentController: SegmentedControler & UIControl = NativeSegmentedControl(items: items.map { $0.title })
        .withoutAutoresizingMask

    open lazy var scrollView = UIScrollView()
        .withoutAutoresizingMask

    open lazy var stackView = UIStackView()
        .withoutAutoresizingMask

    open var currentPage: Int {
        get {
            Int((scrollView.contentOffset.x + (0.5 * scrollView.frame.size.width)) / scrollView.frame.width)
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
        segmentController.currentSegmentIndex
    }

    public var selectedItem: SectionItem {
        items[segmentController.currentSegmentIndex]
    }

    override open func setup() {
        super.setup()
        segmentController.currentSegmentIndex = 0
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
        segmentController.resize(anchors: [.height(48)])
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
    }

    @objc
    open func didSelectSegment(at index: Int) {
        if items.indices.contains(index) {
            scrollView.setContentOffset(CGPoint(x: index * Int(scrollView.bounds.width), y: 0), animated: true)
        }
    }

    // MARK: UIScrollViewDelegate

    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard currentPage != segmentController.currentSegmentIndex else { return }
        segmentController.currentSegmentIndex = currentPage
    }

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollView.contentOffset.y = 0

        segmentController.currentPosition = (scrollView.contentOffset.x + (0.5 * scrollView.frame.width)) / scrollView.contentSize.width
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
}

public extension SegmentedControler where Self: UIControl {}

private class NativeSegmentedControl: UISegmentedControl, SegmentedControler {
    var currentSegmentIndex: Int {
        get {
            selectedSegmentIndex
        }
        set {
            selectedSegmentIndex = newValue
        }
    }

    var currentPosition: Double = 0 {
        didSet {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    var delegate: SegmentedControlerDelegate?

    private let line = {
        $0.backgroundColor = .kitBlue
        $0.layer.cornerRadius = 2
        $0.layer.masksToBounds = true
        $0.frame.size = .init(width: 46, height: 4)
        return $0
    }(UIView())

    private let bottomBorder = {
        $0.backgroundColor = .separatorBorder
        return $0
    }(UIView())

    private var _observer: NSKeyValueObservation?

    override init(items: [Any]?) {
        super.init(items: items)

        _observer = observe(\.selectedSegmentIndex, options: [.new, .old]) { [weak self] _, _ in
            guard let self = self else { return }
            self.delegate?.didSelectSegment(at: self.selectedSegmentIndex)
        }

        if let items, !items.isEmpty {
            currentPosition = 1 / Double(items.count) / 2
        }

        setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)
        setDividerImage(UIImage(), forLeftSegmentState: [], rightSegmentState: [], barMetrics: .default)

        addSubview(line)
        addSubview(bottomBorder.withoutAutoresizingMask)

        bottomBorder.pin(to: self, anchors: [.leading, .trailing, .bottom])
        bottomBorder.resize(anchors: [.height(1)])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        line.bottom = height - 4
        line.left = currentPosition * width - line.width / 2
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        _observer = nil
    }
}
