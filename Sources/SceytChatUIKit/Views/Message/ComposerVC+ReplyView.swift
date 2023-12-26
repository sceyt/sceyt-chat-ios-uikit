//
//  ComposerVC+ActionView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension ComposerVC {
    
    open class ActionView: View {
        
        public lazy var appearance = ComposerVC.appearance {
            didSet {
                setupAppearance()
            }
        }

        open lazy var iconView = UIImageView()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)

        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)
        
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        open lazy var mediaTimestampLabel = ComposerVC.ThumbnailView.TimeLabel()
            .withoutAutoresizingMask

        open lazy var cancelButton = UIButton()
            .withoutAutoresizingMask
        
        open lazy var contentStackView = UIStackView(row: [imageView, titleMessageVStack],
                                                     spacing: 12,
                                                     distribution: .fillProportionally,
                                                     alignment: .center)
            .withoutAutoresizingMask
        
        open lazy var iconTitleHStack = UIStackView(row: [iconView, titleLabel],
                                                    spacing: 4,
                                                    distribution: .fillProportionally,
                                                    alignment: .center)
            .withoutAutoresizingMask
        
        open lazy var titleMessageVStack = UIStackView(column: [iconTitleHStack, messageLabel], spacing: 5, distribution: .fillProportionally)
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            
            backgroundColor = appearance.actionViewBackgroundColor
            
            titleLabel.textAlignment = .left
            titleLabel.lineBreakMode = .byTruncatingTail

            messageLabel.textAlignment = .left
            messageLabel.lineBreakMode = .byTruncatingTail
            
            imageView.isHidden = true
            imageView.clipsToBounds = true
            
            mediaTimestampLabel.isHidden = true
            
            cancelButton.setImage(.replyX, for: .normal)
        }

        override open func setupLayout() {
            super.setupLayout()

            addSubview(contentStackView)
            addSubview(cancelButton)
            imageView.addSubview(mediaTimestampLabel)

            contentStackView.pin(to: self, anchors: [.leading(16), .top(10), .bottom(-10), .trailing(0, .lessThanOrEqual)])
            imageView.resize(anchors: [.width(32), .height(32)])
            cancelButton.pin(to: self, anchors: [.trailing(-16), .top(16, .greaterThanOrEqual), .centerY])
            cancelButton.resize(anchors: [.width(24), .height(24)])
            messageLabel.trailingAnchor.pin(to: cancelButton.leadingAnchor, constant: -8)
            mediaTimestampLabel.pin(to: imageView, anchors: [.leading(4), .bottom(-4), .trailing(0, .lessThanOrEqual)])
        }

        override open func setupAppearance() {
            super.setupAppearance()
            
            imageView.layer.cornerRadius = 4
            imageView.layer.masksToBounds = true
            
            titleLabel.textColor = appearance.actionReplyTitleColor
            titleLabel.font = appearance.actionReplyTitleFont
            
            messageLabel.textColor = appearance.actionMessageColor
            messageLabel.font = appearance.actionMessageFont
        }
    }
}
