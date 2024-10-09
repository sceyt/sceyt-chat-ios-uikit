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
        }

        open lazy var profileImageView = ImageButton()
            .withoutAutoresizingMask
        
        open lazy var headLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var subLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var typingView = Components.typingView
            .init()
            .withoutAutoresizingMask
        
        private lazy var stackView = UIStackView(
            column: [
                headLabel,
                subLabel,
                typingView
            ],
            spacing: 0
        )
            .withoutAutoresizingMask

        open var mode: Mode = .default {
            didSet {
                updateMode()
            }
        }

        open override func setup() {
            super.setup()
            typingView.isHidden = true
            subLabel.isHidden = true
            
            profileImageView.layer.masksToBounds = true
            profileImageView.contentMode = .scaleAspectFill
            
            headLabel.numberOfLines = 1
            headLabel.textAlignment = .left

            subLabel.numberOfLines = 1
            subLabel.textAlignment = .left
            subLabel.minimumScaleFactor = 0.3
            subLabel.adjustsFontSizeToFitWidth = true
        }

        open override func setupAppearance() {
            super.setupAppearance()
            
            headLabel.textColor = appearance.titleLabelAppearance.foregroundColor
            headLabel.font = appearance.titleLabelAppearance.font
            subLabel.textColor = appearance.subtitleLabelAppearance.foregroundColor
            subLabel.font = appearance.subtitleLabelAppearance.font
            typingView.label.textColor = appearance.subtitleLabelAppearance.foregroundColor
            typingView.label.font = appearance.subtitleLabelAppearance.font
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(profileImageView)
            addSubview(typingView)
            addSubview(stackView)
            
            profileImageView.widthAnchor.pin(to: profileImageView.heightAnchor)
            profileImageView.pin(to: self, anchors: [.leading(), .top(4), .bottom(-4)])
            stackView.pin(to: self, anchors: [.trailing(0)])
            stackView.centerYAnchor.pin(to: profileImageView.centerYAnchor)
            stackView.leadingAnchor.pin(to: profileImageView.trailingAnchor, constant: 12)
        }
        
        open override func setupDone() {
            super.setupDone()
            updateMode()
        }
        
        private func updateMode() {
            if mode == .default {
                subLabel.isHidden = false
                typingView.isHidden = true
            } else {
                subLabel.isHidden = true
                typingView.isHidden = false
            }
        }
        
        open override func layoutSubviews() {
            super.layoutSubviews()
            
            profileImageView.layer.cornerRadius = profileImageView.height / 2
        }
    }
}
