//
//  MessageInputViewController+ThumbnailView+FileView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.ThumbnailView {
    open class FileView: View {
        public lazy var appearance = Components.messageInputViewController.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFit)
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var subtitleLabel = UILabel()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            clipsToBounds = true
            layer.cornerRadius = 8
            titleLabel.lineBreakMode = .byTruncatingMiddle
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.fileAttachmentBackgroundColor
            titleLabel.textColor = appearance.fileAttachmentTitleTextColor
            titleLabel.font = appearance.fileAttachmentTitleTextFont
            subtitleLabel.textColor = appearance.fileAttachmentSubtitleTextColor
            subtitleLabel.font = appearance.fileAttachmentSubtitleTextFont
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(subtitleLabel)
            imageView.pin(to: self, anchors: [.top(12, .greaterThanOrEqual), .bottom(-12, .lessThanOrEqual), .leading(12)])
            imageView.heightAnchor.pin(to: imageView.widthAnchor)
            imageView.heightAnchor.pin(constant: 46)
            titleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: 12)
            titleLabel.pin(to: self, anchors: [.top(12, .greaterThanOrEqual), .trailing(-21, .lessThanOrEqual)])
            titleLabel.bottomAnchor.pin(to: imageView.centerYAnchor)
            titleLabel.widthAnchor.pin(lessThanOrEqualToConstant: 120)
            subtitleLabel.leadingAnchor.pin(to: imageView.trailingAnchor, constant: 12)
            subtitleLabel.pin(to: self, anchors: [.bottom(-12, .lessThanOrEqual), .trailing(-21, .lessThanOrEqual)])
            subtitleLabel.topAnchor.pin(to: imageView.centerYAnchor, constant: 4)
        }
    }
}
