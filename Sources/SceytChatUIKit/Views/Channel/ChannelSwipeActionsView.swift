//
//  ChannelSwipeActionsView.swift
//  SceytChatUIKit
//
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

/// The row of swipe action buttons revealed on one side of a channel cell.
///
/// The view is anchored *entirely outside* the cell's corresponding edge and is
/// moved into view by the same `transform` that slides the row's content, so
/// progressive reveal falls out of the cell's `clipsToBounds` for free and a
/// drag costs no layout pass. Only over-drag past `fullRevealWidth` mutates a
/// constraint, and only on a single button.
open class ChannelSwipeActionsView: View {

    public enum Side {
        case leading
        case trailing
    }

    /// Which edge this container is revealed from.
    ///
    /// A settable property rather than an `init` parameter so the view stays
    /// constructible through `Components.channelSwipeActionsView`, which
    /// instantiates from a metatype and therefore only sees required inits.
    open var side: Side = .trailing {
        didSet { updateAccessibilityIdentifier() }
    }

    open lazy var stackView = UIStackView().withoutAutoresizingMask

    /// The buttons, in visual (reading) order.
    public private(set) var buttons: [ChannelSwipeActionButton] = []

    private var widthConstraints: [NSLayoutConstraint] = []

    /// Sum of the buttons' natural widths — the offset at which the row reads as
    /// fully open. `0` means this side has no actions, and the cell must refuse
    /// to open toward it.
    public private(set) var fullRevealWidth: CGFloat = 0

    /// The outermost button — the one closest to the swiped edge — which absorbs
    /// over-drag the way `UISwipeActionsConfiguration`'s first action does.
    private var stretchingWidthConstraint: NSLayoutConstraint?
    private var stretchingNaturalWidth: CGFloat = 0

    open var onAction: ((ChannelSwipeActionsConfiguration.Actions) -> Void)?

    override open func setup() {
        super.setup()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.spacing = 0
        updateAccessibilityIdentifier()
        // While the row is closed these buttons are off-screen; without this,
        // VoiceOver would announce "Delete, Leave, Mute" on every single row.
        // The cell's `accessibilityCustomActions` are the assistive-technology
        // path in; this container is purely visual.
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }

    private func updateAccessibilityIdentifier() {
        accessibilityIdentifier = side == .leading
            ? SceytChatUIKit.AccessibilityIdentifiers.ChannelList.Cell.swipeActionsLeading
            : SceytChatUIKit.AccessibilityIdentifiers.ChannelList.Cell.swipeActionsTrailing
    }

    override open func setupLayout() {
        super.setupLayout()
        addSubview(stackView)
        stackView.pin(to: self)
    }

    /// Rebuilds the buttons. Call only when the action list actually changed —
    /// `ChannelCell.configureSwipeActions(for:)` guards this.
    open func configure(items: [ChannelSwipeActionsConfiguration.ActionItem]) {
        buttons.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        buttons = []
        widthConstraints = []
        stretchingWidthConstraint = nil
        stretchingNaturalWidth = 0
        fullRevealWidth = 0

        // `items[0]` is the action nearest the swiped edge — the same rule
        // `UISwipeActionsConfiguration` uses, and the one a full swipe fires.
        // On the trailing side that edge is the *last* position in reading
        // order, so the list is reversed for layout.
        let ordered = side == .trailing ? Array(items.reversed()) : items

        for item in ordered {
            let button = Components.channelSwipeActionButton.init()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.configure(with: item)
            button.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            let width = naturalWidth(for: item)
            let constraint = button.widthAnchor.pin(constant: width)
            buttons.append(button)
            widthConstraints.append(constraint)
            fullRevealWidth += width
        }

        // The outermost button owns `items.first`.
        if let outerIndex = side == .trailing ? buttons.indices.last : buttons.indices.first {
            stretchingWidthConstraint = widthConstraints[outerIndex]
            stretchingNaturalWidth = widthConstraints[outerIndex].constant
        }
    }

    /// Recomputes the button widths for the current Dynamic Type category.
    open func recomputeWidths() {
        guard !buttons.isEmpty else { return }
        fullRevealWidth = 0
        for (index, button) in buttons.enumerated() {
            guard let item = button.item else { continue }
            let width = naturalWidth(for: item)
            widthConstraints[index].constant = width
            fullRevealWidth += width
        }
        if let stretchingWidthConstraint {
            stretchingNaturalWidth = stretchingWidthConstraint.constant
        }
    }

    /// Absorbs drag past `fullRevealWidth` into the outermost button, so the row
    /// never shows a gap at the swiped edge.
    open func setOverDrag(_ amount: CGFloat) {
        guard let stretchingWidthConstraint else { return }
        let target = stretchingNaturalWidth + max(0, amount)
        guard abs(stretchingWidthConstraint.constant - target) > 0.5 else { return }
        stretchingWidthConstraint.constant = target
    }

    /// `Layouts.iconSize` scaled for the given Dynamic Type category.
    ///
    /// Shared by the button's size constraints and by `naturalWidth(for:)`, so a
    /// button can never be measured at one icon size and laid out at another.
    open class func scaledIconSize(compatibleWith traitCollection: UITraitCollection?) -> CGFloat {
        let font = ChannelSwipeActionsConfiguration.Appearance.titleLabelAppearance.baseFont
        let style = UIFont.preferredTextStyle(for: font.pointSize)
        return UIFontMetrics(forTextStyle: style)
            .scaledValue(for: Layouts.iconSize, compatibleWith: traitCollection)
    }

    /// The width a button needs for its title at the current Dynamic Type
    /// category. Measured with the *scaled* font so buttons grow with Large Text.
    open func naturalWidth(for item: ChannelSwipeActionsConfiguration.ActionItem) -> CGFloat {
        let font = ChannelSwipeActionsConfiguration.Appearance.titleLabelAppearance
            .baseFont.asDynamic(compatibleWith: traitCollection)
        let titleWidth = (item.appearance.title as NSString?)?
            .size(withAttributes: [.font: font]).width ?? 0
        let iconWidth = item.appearance.image == nil
            ? 0
            : Self.scaledIconSize(compatibleWith: traitCollection)
        let content = max(ceil(titleWidth), iconWidth)
        return max(Layouts.minimumWidth, content + Layouts.horizontalPadding * 2)
    }

    @objc private func actionTapped(_ sender: ChannelSwipeActionButton) {
        guard let action = sender.item?.action else { return }
        onAction?(action)
    }
}

public extension ChannelSwipeActionsView {
    enum Layouts {
        /// Minimum tappable width for one action button.
        public static var minimumWidth: CGFloat = 74
        /// Inset between a button's title and its edges.
        public static var horizontalPadding: CGFloat = 12
        /// Spacing between a button's icon and its title.
        public static var iconTitleSpacing: CGFloat = 4
        /// Edge length of an action's icon, before Dynamic Type scaling.
        public static var iconSize: CGFloat = 24
    }
}
