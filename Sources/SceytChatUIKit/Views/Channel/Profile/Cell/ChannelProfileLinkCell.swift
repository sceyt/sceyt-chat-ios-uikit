//
//  ChannelProfileLinkCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileLinkCell: CollectionViewCell {
    typealias Layouts = ChannelLinkListView.Layouts
    
    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFit)

    open lazy var titleLabel = UILabel()
    
    open lazy var linkLabel = UILabel()
    
    open lazy var detailLabel = UILabel()
    
    open lazy var textVStack = UIStackView(column: [titleLabel, linkLabel, detailLabel], spacing: 4)
        .withoutAutoresizingMask
    
    open lazy var contentHStack = UIStackView(row: [iconView, textVStack], 
                                              spacing: Layouts.horizontalPadding,
                                              alignment: .center)
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelLinkListView.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    override open func setup() {
        super.setup()
        
        selectedBackgroundView = UIView()
        iconView.clipsToBounds = true
        iconView.image = Appearance.Images.link
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        selectedBackgroundView?.backgroundColor = Colors.highlighted
        
        iconView.layer.cornerRadius = Layouts.cornerRadius
        
        titleLabel.font = appearance.titleLabelFont
        titleLabel.textColor = appearance.titleLabelTextColor

        linkLabel.font = appearance.linkLabelFont
        linkLabel.textColor = appearance.linkLabelTextColor

        detailLabel.font = appearance.detailLabelFont
        detailLabel.textColor = appearance.detailLabelTextColor
        detailLabel.numberOfLines = 0
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        contentView.addSubview(contentHStack)

        contentHStack.pin(to: contentView, anchors: [
            .leading(Layouts.horizontalPadding), .trailing(-Layouts.horizontalPadding),
            .top(Layouts.verticalPadding), .bottom(-Layouts.verticalPadding)])
        contentHStack.topAnchor.pin(to: contentView.topAnchor, constant: Layouts.verticalPadding)
        
        iconView.resize(anchors: [.height(Layouts.iconSize), .width(Layouts.iconSize)])
//        titleLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 22)
        linkLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 20)
//        detailLabel.heightAnchor.pin(greaterThanOrEqualToConstant: 16)
    }
    
    open var data: ChatMessage.Attachment! {
        didSet {
            guard let data
            else { return }
            linkLabel.text = data.url
            titleLabel.isHidden = (titleLabel.text ?? "").isEmpty
            detailLabel.isHidden = (detailLabel.text ?? "").isEmpty
        }
    }
    
    open var metadata: LinkMetadata? {
        didSet {
            guard let metadata else { return }
            if let data, data.imageDecodedMetadata?.hideLinkDetails == true {
                titleLabel.text = nil
                detailLabel.text = nil
                titleLabel.isHidden = true
                detailLabel.isHidden = true
                iconView.image = Appearance.Images.link
            } else {
                titleLabel.text = metadata.title
                titleLabel.isHidden = (titleLabel.text ?? "").isEmpty
                detailLabel.text = metadata.summary
                detailLabel.isHidden = (detailLabel.text ?? "").isEmpty
                if let image = metadata.image {
                    iconView.image = image
                } else {
                    iconView.image = Appearance.Images.link
                }
            }
        }
    }

    override open func prepareForReuse() {
        super.prepareForReuse()
        
        titleLabel.text = nil
        linkLabel.text = nil
        detailLabel.text = nil
        iconView.image = .link
    }
}
