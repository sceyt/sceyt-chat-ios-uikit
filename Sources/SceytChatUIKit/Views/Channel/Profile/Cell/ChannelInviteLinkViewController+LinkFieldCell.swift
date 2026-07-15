//
//  ChannelInviteLinkViewController+LinkFieldCell.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInviteLinkViewController {
    open class LinkFieldCell: TableViewCell {

        open lazy var linkLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var copyButton = UIButton()
            .withoutAutoresizingMask

        open lazy var containerView = UIView()
            .withoutAutoresizingMask

        open var onCopy: (() -> Void)?

        open override func setup() {
            super.setup()

            linkLabel.numberOfLines = 1
            linkLabel.lineBreakMode = .byTruncatingTail
            copyButton.setImage(appearance.copyImage.withRenderingMode(.alwaysTemplate), for: .normal)
            copyButton.tintColor = appearance.buttonTitleColor
            copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)

            linkLabel.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.linkLabel
            copyButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.ChannelInviteLink.copyButton
        }

        open override func setupLayout() {
            super.setupLayout()

            contentView.addSubview(containerView)
            containerView.addSubview(linkLabel)
            containerView.addSubview(copyButton)

            containerView.pin(to: contentView, anchors: [.leading, .trailing, .top(8), .bottom(-8)])
            containerView.heightAnchor.pin(greaterThanOrEqualToConstant: 44)

            linkLabel.pin(to: containerView, anchors: [.leading(0), .top(8), .bottom(-8)])
            linkLabel.trailingAnchor.pin(to: copyButton.leadingAnchor, constant: -8)

            copyButton.pin(to: containerView, anchors: [.trailing(0), .centerY])
            copyButton.resize(anchors: [.width(32), .height(32)])
        }

        open override var safeAreaInsets: UIEdgeInsets {
            .init(top: 0, left: 2 * ChannelInviteLinkViewController.Layouts.cellHorizontalPadding,
                  bottom: 0, right: 2 * ChannelInviteLinkViewController.Layouts.cellHorizontalPadding)
        }

        open override func setupAppearance() {
            super.setupAppearance()

            backgroundColor = appearance.backgroundColor
            containerView.backgroundColor = appearance.containerBackgroundColor
            containerView.layer.cornerRadius = appearance.cornerRadius
            containerView.layer.borderWidth = appearance.borderWidth
            containerView.layer.borderColor = appearance.borderColor.cgColor

            linkLabel.textColor = appearance.textFieldAppearance.foregroundColor
            linkLabel.font = appearance.textFieldAppearance.font
            linkLabel.backgroundColor = .clear

            copyButton.tintColor = appearance.buttonTitleColor
        }

        @objc open func copyButtonTapped() {
            onCopy?()
        }
    }
}
