//
//  SegmentedControl.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

@objc
public protocol SegmentedControllerDelegate: AnyObject {
    @objc
    func didSelectSegment(at index: Int)
}

@objc
public protocol SegmentedController {
    @objc
    var currentSegmentIndex: Int { get set }
    
    @objc
    var currentPosition: Double { get set }
    
    @objc
    weak var delegate: SegmentedControllerDelegate? { get set }
    
    @objc
    var showCornerRadius: Bool { get set }
}

public extension SegmentedController where Self: UIControl {}

open class SegmentedControl: UIControl, SegmentedController, Configurable {
    
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

    public weak var delegate: SegmentedControllerDelegate?
    
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
        setupDone()
    }
    
    public required init?(coder: NSCoder) {
        segmentedControl = .init().withoutAutoresizingMask
        super.init(coder: coder)
        
        setup()
        setupLayout()
        setupAppearance()
        setupDone()
    }
    
    open func setup() {
        _observer = segmentedControl.observe(\.selectedSegmentIndex, options: [.new, .old]) { [weak self] _, _ in
            guard let self = self else { return }
            self.delegate?.didSelectSegment(at: self.segmentedControl.selectedSegmentIndex)
        }

        if segmentedControl.numberOfSegments > 0 {
            currentPosition = 1 / Double(segmentedControl.numberOfSegments) / 2
        }
    }

    open func setupLayout() {
        addSubview(segmentedControl)
        addSubview(bottomBorder)
        addSubview(line)
        
        segmentedControl.pin(to: self)
        bottomBorder.pin(to: self, anchors: [.leading, .trailing, .bottom])
        bottomBorder.resize(anchors: [.height(Layouts.bottomSeparatorHeight)])
    }

    open func setupAppearance() {
        backgroundColor = appearance.backgroundColor
        layer.cornerRadius = Layouts.cornerRadius
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.masksToBounds = true
        line.backgroundColor = appearance.indicatorColor
        bottomBorder.backgroundColor = appearance.separatorColor
        segmentedControl.setTitleTextAttributes([
            .font: appearance.selectedLabelAppearance.font,
            .foregroundColor: appearance.selectedLabelAppearance.foregroundColor
        ], for: .selected)
        segmentedControl.setTitleTextAttributes([
            .font: appearance.labelAppearance.font,
            .foregroundColor: appearance.labelAppearance.foregroundColor
        ], for: .normal)

        segmentedControl.setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)
        segmentedControl.setDividerImage(UIImage(), forLeftSegmentState: [], rightSegmentState: [], barMetrics: .default)
    }
    
    open func setupDone() {
        
    }
    
    private var lineWidth: CGFloat {
        let normalizedFontSize = (appearance.labelAppearance.font.pointSize + appearance.selectedLabelAppearance.font.pointSize) / 2
        let fontAttributes = [
            NSAttributedString.Key.font: appearance.labelAppearance.font.withSize(normalizedFontSize)
        ]
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

public extension SegmentedControl {
    enum Layouts {
        public static var cornerRadius: CGFloat = 10
        public static var selectedIndicatorHeight: CGFloat = 3
        public static var selectedIndicatorPadding: CGFloat = 4
        public static var bottomSeparatorHeight: CGFloat = 1
    }
}
