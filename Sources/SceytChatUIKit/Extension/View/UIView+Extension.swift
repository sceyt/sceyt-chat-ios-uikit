//
//  UIView+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension UIView {
    var withoutAutoresizingMask: Self {
        translatesAutoresizingMaskIntoConstraints = false
        return self
    }

    @discardableResult
    func contentMode(_ contentMode: UIView.ContentMode) -> Self {
        self.contentMode = contentMode
        return self
    }

    @discardableResult
    func contentCompressionResistancePriorityH(_ priority: UILayoutPriority) -> Self {
        setContentCompressionResistancePriority(priority, for: .horizontal)
        return self
    }

    @discardableResult
    func contentCompressionResistancePriorityV(_ priority: UILayoutPriority) -> Self {
        setContentCompressionResistancePriority(priority, for: .vertical)
        return self
    }

    @discardableResult
    func contentHuggingPriorityH(_ priority: UILayoutPriority) -> Self {
        setContentHuggingPriority(priority, for: .horizontal)
        return self
    }

    @discardableResult
    func contentHuggingPriorityV(_ priority: UILayoutPriority) -> Self {
        setContentCompressionResistancePriority(priority, for: .vertical)
        return self
    }
}

extension UIView {
    var width: CGFloat {
        get { frame.width }
        set { frame.size.width = newValue }
    }

    var height: CGFloat {
        get { frame.height }
        set { frame.size.height = newValue }
    }

    var left: CGFloat {
        get { frame.minX }
        set { frame.origin.x = newValue }
    }

    var right: CGFloat {
        get { frame.maxX }
        set { frame.origin.x = newValue - width }
    }

    var top: CGFloat {
        get { frame.minY }
        set { frame.origin.y = newValue }
    }

    var bottom: CGFloat {
        get { frame.maxY }
        set { frame.origin.y = newValue - height }
    }
}

extension UIStackView {
    convenience init(row views: UIView..., spacing: CGFloat = 0, distribution: Distribution = .fill, alignment: Alignment = .fill) {
        self.init(views, axis: .horizontal, spacing: spacing, distribution: distribution, alignment: alignment)
    }

    convenience init(column views: UIView..., spacing: CGFloat = 0, distribution: Distribution = .fill, alignment: Alignment = .fill) {
        self.init(views, axis: .vertical, spacing: spacing, distribution: distribution, alignment: alignment)
    }

    convenience init(row views: [UIView], spacing: CGFloat = 0, distribution: Distribution = .fill, alignment: Alignment = .fill) {
        self.init(views, axis: .horizontal, spacing: spacing, distribution: distribution, alignment: alignment)
    }

    convenience init(column views: [UIView], spacing: CGFloat = 0, distribution: Distribution = .fill, alignment: Alignment = .fill) {
        self.init(views, axis: .vertical, spacing: spacing, distribution: distribution, alignment: alignment)
    }

    convenience init(_ views: [UIView], axis: NSLayoutConstraint.Axis, spacing: CGFloat = 0, distribution: Distribution = .fill, alignment: Alignment = .fill) {
        self.init(arrangedSubviews: views)
        self.axis = axis
        self.spacing = spacing
        self.distribution = distribution
        self.alignment = alignment
    }

    func addArrangedSubviews(_ views: [UIView]) {
        views.forEach {
            addArrangedSubview($0)
        }
    }

    func addBackground(_ color: UIColor? = nil) {
        let bg = UIView()
        bg.backgroundColor = color
        insertSubview(bg.withoutAutoresizingMask, at: 0)
        bg.pin(to: self)
    }
}

extension UIView {
    func frameRelativeToWindow() -> CGRect {
        return convert(bounds, to: nil)
    }
    
    func frameRelativeTo(view: UIView) -> CGRect {
        return convert(bounds, to: view)
    }
}

public extension UIView {
    func contains(
        gestureRecognizer: UIGestureRecognizer,
        contentInsets: UIEdgeInsets = .zero
    ) -> Bool {
        let location = gestureRecognizer.location(in: self)
        var rect = bounds
        if contentInsets != .zero {
            rect = rect.inset(by: contentInsets)
        }
        return rect.contains(location)
    }
}
