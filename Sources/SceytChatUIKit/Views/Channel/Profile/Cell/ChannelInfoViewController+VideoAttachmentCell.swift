//
//  ChannelInfoViewController+VideoAttachmentCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class VideoAttachmentCell: ChannelInfoViewController.AttachmentCell {
        
        open lazy var timeLabel = Components.timeLabel
            .init()
            .withoutAutoresizingMask
        
        open override func setup() {
            super.setup()
            
            timeLabel.isUserInteractionEnabled = false
            timeLabel.stackView.spacing = 0
        }
        
        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(timeLabel)
            imageView.pin(to: self)
            timeLabel.pin(to: imageView, anchors: [.bottom(-8), .trailing(-8)])
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            timeLabel.iconView.image = appearance.videoDurationIcon
            timeLabel.backgroundColor = appearance.durationLabelAppearance.backgroundColor
            timeLabel.textLabel.font = appearance.durationLabelAppearance.font
            timeLabel.textLabel.textColor = appearance.durationLabelAppearance.foregroundColor
        }
        
        open override var data: MessageLayoutModel.AttachmentLayout? {
            didSet {
                guard let data
                else { return }
                if let duration = data.attachment.imageDecodedMetadata?.duration, duration > 0 {
                    timeLabel.text = appearance.durationFormatter.format(TimeInterval(duration))
                } else {
                    timeLabel.text = ""
                }
                imageView.image = data.thumbnail
                imageView.setup(
                    previewer: { self.previewer?() },
                    item: PreviewItem.attachment(data.attachment)
                )
            }
        }
    }
}
