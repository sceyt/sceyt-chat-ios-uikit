//
//  MessageInputViewController+ThumbnailView+TimeLabel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.ThumbnailView {
    open class TimeLabel: View {
        public lazy var appearance = Components.messageInputSelectedMediaView.appearance.attachmentDurationLabelAppearance {
            didSet {
                setupAppearance()
            }
        }

        open lazy var timeLabel: UILabel = {
            $0.font = Fonts.regular.withSize(12)
            return $0.withoutAutoresizingMask
        }(UILabel())
        
        override open func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.backgroundColor
            timeLabel.font = appearance.font
            timeLabel.textColor = appearance.foregroundColor
        }
        
        override open func setupLayout() {
            super.setupLayout()
            addSubview(timeLabel)
            timeLabel.pin(to: self, anchors: [.leading(6), .top(3), .bottom(-3), .trailing(-6)])
        }
        
        var text: String? {
            set { timeLabel.text = newValue }
            get { timeLabel.text }
        }
        
        override open func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = bounds.height / 2
        }
    }
}
