//
//  ChannelLinkCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelLinkCell: CollectionViewCell {
    
    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFill)

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask
        .contentHuggingPriorityV(.defaultHigh)

    open lazy var linkLabel = UILabel()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityV(.defaultLow)
    
    open lazy var separatorView = UIView()
        .withoutAutoresizingMask
    
    open var linkMetadataProvider = LinkMetadataProvider.default
    private var linkTask: LinkMetadataProvider.Task?

    public lazy var appearance = ChannelLinkListView.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open override func setup() {
        super.setup()
        iconView.clipsToBounds = true
        iconView.image = Appearance.Images.link
        
        titleLabel.lineBreakMode = .byTruncatingMiddle
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        titleLabel.font = appearance.titleLabelFont
        titleLabel.textColor = appearance.titleLabelTextColor
        
        linkLabel.font = appearance.linkLabelFont
        linkLabel.textColor = appearance.linkLabelTextColor
        separatorView.backgroundColor = appearance.separatorColor
    }
    
    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(linkLabel)
        contentView.addSubview(separatorView)

        iconView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: 12)
        iconView.centerYAnchor.pin(to: contentView.centerYAnchor)
        iconView.widthAnchor.pin(constant: 40)
        iconView.heightAnchor.pin(constant: 40)
        titleLabel.leadingAnchor.pin(to: iconView.trailingAnchor, constant: 12)
        titleLabel.topAnchor.pin(to: iconView.topAnchor)
        titleLabel.trailingAnchor.pin(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8)

        linkLabel.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        linkLabel.topAnchor.pin(to: titleLabel.bottomAnchor, constant: 2)
        linkLabel.trailingAnchor.pin(lessThanOrEqualTo: contentView.trailingAnchor, constant: -8)
        linkLabel.bottomAnchor.pin(lessThanOrEqualTo: contentView.bottomAnchor)
        
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing()])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
    }
    
    open var data: ChatMessage.Attachment! {
        didSet {
            guard let data,
                    let link = data.url,
                  let url = URL(string: link)
            else { return }
            
            linkLabel.text = url.absoluteString
            linkTask = linkMetadataProvider.fetch(url: url) { [weak self] result in
                guard case .success(let metadata) = result,
                        metadata.url.absoluteString == self?.linkLabel.text
                else { return }
                self?.titleLabel.text = metadata.title
                if let image = metadata.icon ?? metadata.image {
                    self?.iconView.image = image
                }
            }
        }
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        linkTask?.cancel()
        titleLabel.text = nil
        iconView.image = Appearance.Images.link
    }
}
