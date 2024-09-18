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
            timeLabel.iconView.image = nil
            timeLabel.stackView.spacing = 0
        }
        
        public lazy var appearance = Components.channelInfoMediaCollectionView.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(timeLabel)
            imageView.pin(to: self)
            timeLabel.pin(to: imageView, anchors: [.bottom(-8), .trailing(-8)])
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            timeLabel.backgroundColor = appearance.videoTimeBackgroundColor
            timeLabel.textLabel.font = appearance.videoTimeTextFont
            timeLabel.textLabel.textColor = appearance.videoTimeTextColor
        }
        
        open override var data: MessageLayoutModel.AttachmentLayout? {
            didSet {
                guard let data
                else { return }
                if let duration = data.attachment.imageDecodedMetadata?.duration, duration > 0 {
                    timeLabel.text = SceytChatUIKit.shared.formatters.mediaDurationFormatter.format(TimeInterval(duration))
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
