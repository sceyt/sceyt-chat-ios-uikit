//
//  MessageInputViewController+ThumbnailView+MediaView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.ThumbnailView {
    open class MediaView: View {
        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)
        
        open lazy var timeLabel = Components.messageInputThumbnailViewTimeLabel.init()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            timeLabel.isHidden = true
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(imageView)
            addSubview(timeLabel)
            imageView.pin(to: self)
            timeLabel.pin(to: self, anchors: [.leading(0, .greaterThanOrEqual), .bottom(-4), .trailing(-4)])
            imageView.heightAnchor.pin(to: imageView.widthAnchor)
        }
    }
}
