//
//  ChannelMediaVideoCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelMediaVideoCell: CollectionViewCell {
    
    open lazy var imageView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFill)
    
    open lazy var timeLabel = Components.timeLabel
        .init()
        .withoutAutoresizingMask
    
    open override func setup() {
        super.setup()
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
        timeLabel.iconView.image = nil
        timeLabel.stackView.spacing = 0
    }
    
    public lazy var appearance = ChannelMediaListView.appearance {
        didSet {
            setupAppearance()
        }
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(imageView)
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
    
    open var data: ChatMessage.Attachment! {
        didSet {
            if let duration = data.imageDecodedMetadata?.duration, duration > 0 {
                timeLabel.text = Formatters.videoAssetDuration.format(TimeInterval(duration))
            } else {
                timeLabel.text = ""
            }
            guard let path = fileProvider.thumbnailFile(for: data, preferred: Components.messageLayoutModel.defaults.imageAttachmentSize)
            else {
                if let data = data.imageDecodedMetadata?.thumbnailData {
                    imageView.image = UIImage(data: data)
                } else if let thumbnail = data.imageDecodedMetadata?.thumbnail,
                          let image = Components.imageBuilder.image(from: thumbnail)
                {
                    imageView.image = image
                } else {
                    imageView.image = nil
                }
                return
            }
            if let image = UIImage(contentsOfFile: path) {
                imageView.image = image
            }
        }
    }
    
    open var previewer: AttachmentPreviewDataSource? {
        didSet {
            imageView.setup(
                previewer: previewer,
                item: PreviewItem.attachment(data)
            )
        }
    }
}
