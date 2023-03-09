//
//  ChannelVC+TitleView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

extension ChannelVC {

    open class TitleView: View {

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
            profileImageView.layer.cornerRadius = 18
            profileImageView.contentMode = .scaleAspectFill
            
            headLabel.numberOfLines = 1
            headLabel.textAlignment = .left
            headLabel.minimumScaleFactor = 0.3

            subLabel.numberOfLines = 1
            subLabel.textAlignment = .left
            subLabel.minimumScaleFactor = 0.3
        }

        open override func setupAppearance() {
            super.setupAppearance()
            
        }

        open override func setupLayout() {
            super.setupLayout()
            addSubview(profileImageView)
            addSubview(headLabel)
            addSubview(subLabel)
            addSubview(typingView)
            profileImageView.widthAnchor.pin(to: profileImageView.heightAnchor)
            profileImageView.pin(to: self, anchors: [.leading(), .top(0, .greaterThanOrEqual), .bottom(0, .lessThanOrEqual)])
            profileImageView.heightAnchor.pin(constant: 36)
            headLabel.pin(to: self, anchors: [.top(), .trailing(0, .lessThanOrEqual)])
            headLabel.leadingAnchor.pin(to: profileImageView.trailingAnchor, constant: 12)
            
            subLabel.pin(to: self, anchors: [.bottom(), .trailing(0, .lessThanOrEqual)])
            subLabel.topAnchor.pin(to: headLabel.bottomAnchor)
            subLabel.leadingAnchor.pin(to: profileImageView.trailingAnchor, constant: 12)
            
            typingView.pin(to: self, anchors: [.bottom(), .trailing(0, .lessThanOrEqual), .centerX()])
            typingView.topAnchor.pin(to: headLabel.bottomAnchor)
            typingView.leadingAnchor.pin(to: profileImageView.trailingAnchor, constant: 12)
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
    }
}
