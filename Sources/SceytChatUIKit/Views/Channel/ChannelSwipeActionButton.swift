//
//  ChannelSwipeActionButton.swift
//  SceytChatUIKit
//
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

/// A single button inside a channel row's swipe actions.
///
/// Mirrors what `UISwipeActionsConfiguration` used to render: a centered,
/// optionally-iconed title on a solid background. The channel list draws its own
/// swipe actions because UIKit's cannot stay open across a channel reorder — see
/// `ChannelListViewController.openSwipe`.
open class ChannelSwipeActionButton: Button {

    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFit)

    /// The action's title.
    ///
    /// Not `UIButton`'s own `titleLabel`, which this implementation
    /// deliberately does not use: the icon and title are stacked vertically,
    /// which the built-in label cannot do.
    open lazy var actionTitleLabel = UILabel().withoutAutoresizingMask

    open lazy var stackView = UIStackView(arrangedSubviews: [iconView, actionTitleLabel])
        .withoutAutoresizingMask

    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?

    /// The action this button performs, or `nil` before `configure(with:)`.
    public private(set) var item: ChannelSwipeActionsConfiguration.ActionItem?

    override open func setup() {
        super.setup()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = ChannelSwipeActionsView.Layouts.iconTitleSpacing
        // Taps belong to the button, not to the labels inside it.
        stackView.isUserInteractionEnabled = false

        actionTitleLabel.textAlignment = .center
        actionTitleLabel.numberOfLines = 2
        actionTitleLabel.adjustsFontForContentSizeCategory = true
        // At the largest Dynamic Type categories the title has to shrink rather
        // than force the button unboundedly wide.
        actionTitleLabel.adjustsFontSizeToFitWidth = true
        actionTitleLabel.minimumScaleFactor = 0.8
    }

    override open func setupLayout() {
        super.setupLayout()
        iconWidthConstraint = iconView.widthAnchor.pin(constant: 0)
        iconHeightConstraint = iconView.heightAnchor.pin(constant: 0)
        updateIconSize()
        addSubview(stackView)
        stackView.pin(to: self, anchors: [.centerX(), .centerY()])
        stackView.pin(to: self, anchors: [
            .leading(ChannelSwipeActionsView.Layouts.horizontalPadding, .greaterThanOrEqual),
            .trailing(-ChannelSwipeActionsView.Layouts.horizontalPadding, .lessThanOrEqual)
        ])
    }

    override open func setupAppearance() {
        super.setupAppearance()
        let titleAppearance = ChannelSwipeActionsConfiguration.Appearance.titleLabelAppearance
        actionTitleLabel.font = titleAppearance.baseFont.asDynamic(compatibleWith: traitCollection)
        actionTitleLabel.textColor = titleAppearance.foregroundColor
        iconView.tintColor = titleAppearance.foregroundColor
        // The background is the action's own color, so it is applied in
        // `configure(with:)` rather than here.
    }

    /// Resizes the icon for the current Dynamic Type category, so it grows
    /// alongside the title rather than staying pinned to the asset's own size.
    open func updateIconSize() {
        let size = ChannelSwipeActionsView.scaledIconSize(compatibleWith: traitCollection)
        iconWidthConstraint?.constant = size
        iconHeightConstraint?.constant = size
    }

    open func configure(with item: ChannelSwipeActionsConfiguration.ActionItem) {
        self.item = item
        actionTitleLabel.text = item.appearance.title
        actionTitleLabel.isHidden = item.appearance.title?.isEmpty ?? true
        iconView.image = item.appearance.image
        // The shipped appearances carry no image, so this keeps today's
        // title-only rendering byte-for-byte.
        iconView.isHidden = item.appearance.image == nil
        backgroundColor = item.appearance.backgroundColor
        accessibilityLabel = item.appearance.title
        accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelList.Cell
            .swipeAction(item.action.identifierName)
        setupAppearance()
    }

    override open var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory
                != previousTraitCollection?.preferredContentSizeCategory
        else { return }
        setupAppearance()
        updateIconSize()
    }
}
