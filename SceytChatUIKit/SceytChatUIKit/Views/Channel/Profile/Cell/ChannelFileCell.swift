//
//  ChannelFileCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelFileCell: CollectionViewCell {
    
    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFill)

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var sizeLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var dateLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var separatorView = UIView()
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelFileListView.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open override func setup() {
        super.setup()
        iconView.image = Appearance.Images.file
        titleLabel.lineBreakMode = .byTruncatingMiddle
        iconView.layer.cornerRadius = 8
        iconView.clipsToBounds = true
    }

    open override func setupAppearance() {
        super.setupAppearance()
        
        titleLabel.font = appearance.titleLabelFont
        titleLabel.textColor = appearance.titleLabelTextColor
        sizeLabel.font = appearance.sizeLabelFont
        sizeLabel.textColor = appearance.sizeLabelTextColor
        dateLabel.font = appearance.dateLabelFont
        dateLabel.textColor = appearance.dateLabelTextColor
        separatorView.backgroundColor = appearance.separatorColor
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(sizeLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(separatorView)

        iconView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: 16)
        iconView.centerYAnchor.pin(to: contentView.centerYAnchor)
        iconView.widthAnchor.pin(constant: 40)
        iconView.heightAnchor.pin(constant: 40)
        titleLabel.leadingAnchor.pin(to: iconView.trailingAnchor, constant: 12)
        titleLabel.topAnchor.pin(to: iconView.topAnchor)
        titleLabel.trailingAnchor.pin(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8)
        sizeLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        sizeLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 4)
        dateLabel.leadingAnchor.pin(to: sizeLabel.trailingAnchor, constant: 4)
        dateLabel.topAnchor.pin(to: sizeLabel.topAnchor)
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing()])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }
    
    open var data: ChatMessage.Attachment! {
        didSet {
            titleLabel.text = data.name ?? data.originUrl.lastPathComponent
            sizeLabel.text = Formatters.fileSize.format(data.uploadedFileSize) + ", "
            dateLabel.text = Formatters.channelProfileFileTimestamp.format(data.createdAt)
            if let path = fileProvider.thumbnailFile(for: data, preferred: .init(width: 40, height: 40)),
            let image = UIImage(contentsOfFile: path) {
                iconView.image = image
            }
        }
    }
}
