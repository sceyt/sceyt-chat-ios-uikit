//
//  MessageInputViewController+MessageActionsView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController {
    
    open class MessageActionsView: View {
        
        public lazy var appearance = MessageInputViewController.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var iconView = UIImageView()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)
        
        open lazy var playView = UIImageView()
            .withoutAutoresizingMask

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)

        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)
        
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        open lazy var mediaTimestampLabel = Components.messageInputThumbnailViewTimeLabel.init()
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
                        
            titleLabel.textAlignment = .left
            titleLabel.lineBreakMode = .byTruncatingTail

            messageLabel.textAlignment = .left
            messageLabel.lineBreakMode = .byTruncatingTail
            
            imageView.isHidden = true
            imageView.clipsToBounds = true
            
            mediaTimestampLabel.isHidden = true
            
            cancelButton.setImage(appearance.closeIcon, for: .normal)
            
            playView.image = .replyPlay
        }

        override open func setupLayout() {
            super.setupLayout()
            
            imageView.addSubview(playView)
            playView.pin(to: imageView, anchors: [.centerX, .centerY])

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
        }
    }
}
