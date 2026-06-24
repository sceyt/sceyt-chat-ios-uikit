//
//  BadgeLabel.swift
//  SceytChatUIKit
//
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

/// A self-sizing pill badge backed by a single `UILabel`.
///
/// Unlike `BadgeView` — a container whose width has to be coaxed out of Auto
/// Layout via the inner label's constraints — `BadgeLabel` carries the width in
/// its own `intrinsicContentSize`. The badge therefore always tracks the text:
/// counts like `99+` grow, while short values stay a circle thanks to
/// `minWidth` and `minHeight`.
open class BadgeLabel: UILabel {

    /// Horizontal padding added on each side of the text, folded into
    /// `intrinsicContentSize`.
    open var horizontalPadding: CGFloat = 3 {
        didSet { invalidateIntrinsicContentSize() }
    }

    /// Lower bound on the width so short values (e.g. a single digit, or an
    /// empty "unread" dot) render as a circle rather than a thin sliver.
    open var minWidth: CGFloat = 20 {
        didSet { invalidateIntrinsicContentSize() }
    }

    /// Lower bound on the height so badges keep a stable visual size even when
    /// their text has a smaller intrinsic line height.
    open var minHeight: CGFloat = 20 {
        didSet { invalidateIntrinsicContentSize() }
    }

    /// When `true`, the badge hides itself whenever its text is empty.
    public var hidesWhenEmpty = true {
        didSet { updateVisibility() }
    }

    public required init() {
        super.init(frame: .zero)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        textAlignment = .center
        numberOfLines = 1
        clipsToBounds = true
    }

    /// Mirrors `BadgeView.value` so call sites stay unchanged.
    open var value: String? {
        get { text }
        set {
            text = newValue
            updateVisibility()
        }
    }

    open override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        let contentWidth = (text?.isEmpty ?? true) ? 0 : size.width + horizontalPadding * 2
        size.width = max(contentWidth, minWidth)
        size.height = max(size.height, minHeight)
        return size
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        // Pill: fully rounded ends regardless of width.
        layer.cornerRadius = 0.5 * min(bounds.width, bounds.height)
    }

    private func updateVisibility() {
        guard hidesWhenEmpty else { return }
        isHidden = text?.isEmpty ?? true
    }
}
