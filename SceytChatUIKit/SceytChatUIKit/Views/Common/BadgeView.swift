//
//  BadgeView.swift
//  SceytChatUIKit
//

import UIKit

open class BadgeView: View {

    public var hidesWhenEmpty = true {
        didSet {
            updateVisibility()
        }
    }
    
    open lazy var label = UILabel()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.defaultHigh)

    open override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 0.5 * min(bounds.width, bounds.height)
    }
    
    open override func setup() {
        super.setup()
        label.textAlignment = .center
    }

    open override func setupLayout() {
        super.setupLayout()
        addSubview(label)
        label.pin(to: self, anchors: [.centerX, .centerY])
        label.leadingAnchor.pin(to: leadingAnchor, constant: 3).priority(.defaultLow)
        label.trailingAnchor.pin(to: trailingAnchor, constant: -3).priority(.defaultLow)
        label.topAnchor.pin(to: topAnchor).priority(.defaultLow)
        label.bottomAnchor.pin(to: bottomAnchor).priority(.defaultLow)
    }

    open override func setupAppearance() {
        super.setupAppearance()
        label.clipsToBounds = true
        label.lineBreakMode = .byCharWrapping
    }

    open var value: String? {
        set {
            label.text = newValue
            updateVisibility()
        }
        get { label.text }
    }

    open var font: UIFont? {
        set { label.font = newValue }
        get { label.font }
    }

    open var textColor: UIColor? {
        set { label.textColor = newValue }
        get { label.textColor }
    }

    open override func setContentHuggingPriority(
        _ priority: UILayoutPriority,
        for axis: NSLayoutConstraint.Axis) {
        label.setContentHuggingPriority(priority, for: axis)
    }

    open override func setContentCompressionResistancePriority(
        _ priority: UILayoutPriority,
        for axis: NSLayoutConstraint.Axis) {
        label.setContentCompressionResistancePriority(priority, for: axis)
    }
    
    private func updateVisibility() {
        isHidden = (label.text == nil || label.text?.isEmpty == .some(true))
    }
}
