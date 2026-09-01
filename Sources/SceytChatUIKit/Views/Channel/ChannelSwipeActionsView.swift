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
///
/// On top of that slide, `setRevealedWidth(_:mirrored:)` gives each button its
/// own translation so all of them grow from zero together — see that method for
/// why the row would otherwise arrive one button at a time.
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

    /// The buttons' unstretched widths and their cumulative distance from the
    /// container's leading edge, in layout order.
    ///
    /// Kept apart from `widthConstraints` because `setOverDrag(_:)` mutates one
    /// of those constants, and the reveal maths has to keep working off the
    /// natural geometry while it does.
    private var naturalWidths: [CGFloat] = []
    private var naturalOffsets: [CGFloat] = []

    /// How much of this side is currently exposed, and whether the row is
    /// mirrored. Retained so a rebuild or a Dynamic Type change can re-apply the
    /// reveal without the cell having to drive it again.
    private var revealedWidth: CGFloat = 0
    private var isMirrored = false

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
        naturalWidths = []
        naturalOffsets = []
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
            naturalOffsets.append(fullRevealWidth)
            naturalWidths.append(width)
            fullRevealWidth += width
        }

        // The outermost button owns `items.first`.
        if let outerIndex = side == .trailing ? buttons.indices.last : buttons.indices.first {
            stretchingWidthConstraint = widthConstraints[outerIndex]
            stretchingNaturalWidth = widthConstraints[outerIndex].constant
        }

        updateButtonDepths()
        applyReveal()
    }

    /// Stacks the buttons so the one nearest the swiped edge paints over its
    /// neighbours.
    ///
    /// Mid-reveal every button is wider than the slice of it the row is showing
    /// and hangs over the button further in (see
    /// `setRevealedWidth(_:mirrored:)`); the seam the row must show is the outer
    /// button's inner edge, so the outer button has to win.
    ///
    /// Drawing order rather than `zPosition`, which `CALayer.render(in:)` — and
    /// so any snapshot-based test — ignores. `UIStackView` keeps `subviews`
    /// order independent of `arrangedSubviews`, so reordering here changes only
    /// what paints on top, not the layout.
    private func updateButtonDepths() {
        let backToFront = side == .leading ? Array(buttons.reversed()) : buttons
        backToFront.forEach(stackView.bringSubviewToFront)
    }

    /// Recomputes the button widths for the current Dynamic Type category.
    open func recomputeWidths() {
        guard !buttons.isEmpty else { return }
        fullRevealWidth = 0
        for (index, button) in buttons.enumerated() {
            guard let item = button.item else { continue }
            let width = naturalWidth(for: item)
            widthConstraints[index].constant = width
            naturalOffsets[index] = fullRevealWidth
            naturalWidths[index] = width
            fullRevealWidth += width
        }
        if let stretchingWidthConstraint {
            stretchingNaturalWidth = stretchingWidthConstraint.constant
        }
        applyReveal()
    }

    /// Positions the buttons for `revealed` points of exposure, `mirrored` when
    /// the row lays out right-to-left.
    ///
    /// Sliding the container alone reveals it edge-first: the button nearest the
    /// content is out from behind the row immediately at full width, and the
    /// outer ones only start appearing once it has cleared. Reference behaviour
    /// is that every action widens from zero at the same rate.
    ///
    /// So each button additionally *lags* the container by the natural width of
    /// everything between it and the content — the buttons it is still waiting
    /// on — scaled by how much of the reveal is left. That makes button `i`'s
    /// exposed slice exactly `progress × width`, while its content stays laid out
    /// at full width and hangs off the inner edge, so a title slides in rather
    /// than squeezing. The lag reaches zero at full reveal, so this is purely a
    /// reveal-time effect: the open row and any over-drag past it are untouched.
    ///
    /// Translation only — no constraint is disturbed, so a drag still costs no
    /// layout pass.
    open func setRevealedWidth(_ revealed: CGFloat, mirrored: Bool) {
        revealedWidth = max(0, revealed)
        isMirrored = mirrored
        applyReveal()
    }

    private func applyReveal() {
        guard fullRevealWidth > 0 else { return }
        let remaining = 1 - min(1, revealedWidth / fullRevealWidth)
        // Positive lag points from the swiped edge toward the content, which is
        // the +x direction for a leading row and -x for a trailing one — flipped
        // again when the whole row is mirrored.
        let direction: CGFloat = (side == .leading ? 1 : -1) * (isMirrored ? -1 : 1)
        for (index, button) in buttons.enumerated() {
            let lag = side == .leading
                ? fullRevealWidth - naturalOffsets[index] - naturalWidths[index]
                : naturalOffsets[index]
            button.transform = CGAffineTransform(translationX: direction * remaining * lag, y: 0)
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
