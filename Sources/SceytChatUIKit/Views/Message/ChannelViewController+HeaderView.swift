//
//  ChannelViewController+HeaderView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController {

    open class HeaderView: View {

        public enum Mode {
            case `default`
            case typing
            case recording
        }

        open lazy var profileImageView = ImageButton()
            .withoutAutoresizingMask
        
        open lazy var headLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var subLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var channelEventView = Components.channelEventView
            .init()
            .withoutAutoresizingMask

        open lazy var tapButton: UIButton = {
            let button = UIButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.backgroundColor = .clear
            return button
        }()
        
        open override var intrinsicContentSize: CGSize {
            return CGSize(width: CGFloat.greatestFiniteMagnitude, height: UIView.noIntrinsicMetric)
        }

        private lazy var stackView = UIStackView(
            column: [
                headLabel,
                subLabel,
                channelEventView
            ],
            spacing: 0
        )
        .withoutAutoresizingMask

        private var _mode: Mode = .default

        
        open var mode: Mode {
            get { _mode }
            set {
                guard newValue != _mode else { return }

                let oldValue = _mode
                _mode = newValue
                updateMode()
            }
        }

        open override func setup() {
            super.setup()
            channelEventView.isHidden = true
            subLabel.isHidden = true
            
            profileImageView.layer.masksToBounds = true
            profileImageView.contentMode = .scaleAspectFill
            profileImageView.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.avatar

            headLabel.numberOfLines = 1
            headLabel.textAlignment = .left
            headLabel.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.titleLabel

            subLabel.numberOfLines = 1
            subLabel.textAlignment = .left
            subLabel.minimumScaleFactor = 0.3
            subLabel.adjustsFontSizeToFitWidth = true
            subLabel.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.subtitleLabel
        }

        open override func setupAppearance() {
            super.setupAppearance()
            
            headLabel.textColor = appearance.titleLabelAppearance.foregroundColor
            headLabel.font = appearance.titleLabelAppearance.font
            subLabel.textColor = appearance.subtitleLabelAppearance.foregroundColor
            subLabel.font = appearance.subtitleLabelAppearance.font
            channelEventView.label.textColor = appearance.subtitleLabelAppearance.foregroundColor
            channelEventView.label.font = appearance.subtitleLabelAppearance.font
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(profileImageView)
            addSubview(channelEventView)
            addSubview(stackView)
            addSubview(tapButton)

            profileImageView.widthAnchor.pin(to: profileImageView.heightAnchor)
            profileImageView.heightAnchor.pin(constant: 36)
            profileImageView.pin(to: self, anchors: [.leading(), .centerY])

            stackView.pin(to: self, anchors: [.trailing(-8)])
            stackView.centerYAnchor.pin(to: profileImageView.centerYAnchor)
            stackView.leadingAnchor.pin(to: profileImageView.trailingAnchor, constant: 12)

            tapButton.pin(to: self, anchors: [.leading(), .trailing(), .top(), .bottom()])
        }
        
        open override func setupDone() {
            super.setupDone()
            updateMode()
        }
        
        private func updateMode() {
            if mode == .default {
                subLabel.isHidden = false
                channelEventView.isHidden = true
            } else {
                subLabel.isHidden = true
                channelEventView.isHidden = false
            }
        }
    }
}
