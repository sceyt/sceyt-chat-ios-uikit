//
//  ChannelInfoViewController+LinkCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class LinkCell: CollectionViewCell {
        typealias Layouts = ChannelInfoViewController.LinkCollectionView.Layouts
        
        open lazy var iconView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFit)
        
        open lazy var titleLabel = UILabel()
        
        open lazy var linkLabel = UILabel()
        
        open lazy var detailLabel = UILabel()
        
        open lazy var textVStack = UIStackView(column: [titleLabel, linkLabel, detailLabel], spacing: Layouts.textSpacing)
            .withoutAutoresizingMask
        
        open lazy var contentHStack = UIStackView(row: [iconView, textVStack],
                                                  spacing: Layouts.horizontalPadding,
                                                  alignment: .center)
            .withoutAutoresizingMask
                
        override open func setup() {
            super.setup()
            
            selectedBackgroundView = UIView()
            iconView.clipsToBounds = true
            iconView.contentMode = .scaleAspectFill
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            selectedBackgroundView?.backgroundColor = appearance.selectedBackgroundColor
            
            iconView.image = appearance.linkPreviewAppearance.placeholderIcon
            iconView.layer.cornerRadius = Layouts.cornerRadius
            
            // Line caps must stay in sync with LinkCollectionView.preferredCellHeight,
            // which reserves exactly 1 + 1 + 2 lines for every row.
            titleLabel.font = appearance.linkPreviewAppearance.titleLabelAppearance.font
            titleLabel.textColor = appearance.linkPreviewAppearance.titleLabelAppearance.foregroundColor
            titleLabel.numberOfLines = 1
            titleLabel.lineBreakMode = .byTruncatingTail

            linkLabel.font = appearance.linkLabelAppearance.font
            linkLabel.textColor = appearance.linkLabelAppearance.foregroundColor
            linkLabel.numberOfLines = 1
            linkLabel.lineBreakMode = .byTruncatingTail

            detailLabel.font = appearance.linkPreviewAppearance.descriptionLabelAppearance.font
            detailLabel.textColor = appearance.linkPreviewAppearance.descriptionLabelAppearance.foregroundColor
            detailLabel.numberOfLines = 2
            detailLabel.lineBreakMode = .byTruncatingTail
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(contentHStack)
            
            contentHStack.pin(to: contentView, anchors: [
                .leading(Layouts.horizontalPadding), .trailing(-Layouts.horizontalPadding),
                .top(Layouts.verticalPadding), .bottom(-Layouts.verticalPadding)])
            
            iconView.resize(anchors: [.height(Layouts.iconSize), .width(Layouts.iconSize)])
        }
        
        open var data: ChatMessage.Attachment! {
            didSet {
                guard let data else { return }
                linkLabel.text = data.url
                titleLabel.isHidden = (titleLabel.text ?? "").isEmpty
                detailLabel.isHidden = (detailLabel.text ?? "").isEmpty
                updateLinkNumberOfLines()
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
                    iconView.image = appearance.linkPreviewAppearance.placeholderIcon
                } else {
                    titleLabel.text = metadata.title
                    titleLabel.isHidden = (titleLabel.text ?? "").isEmpty
                    detailLabel.text = metadata.summary
                    detailLabel.isHidden = (detailLabel.text ?? "").isEmpty
                    if let image = metadata.image {
                        iconView.image = image
                    } else {
                        iconView.image = appearance.linkPreviewAppearance.placeholderIcon
                    }
                }
                updateLinkNumberOfLines()
            }
        }

        /// The row reserves 1 title + 1 URL + 2 description lines; while only the URL is
        /// visible it may spread onto two of those lines before truncating.
        open func updateLinkNumberOfLines() {
            linkLabel.numberOfLines = (titleLabel.isHidden && detailLabel.isHidden) ? 2 : 1
        }
        
        override open func prepareForReuse() {
            super.prepareForReuse()

            data = nil
            metadata = nil
            titleLabel.text = nil
            linkLabel.text = nil
            detailLabel.text = nil
            titleLabel.isHidden = true
            detailLabel.isHidden = true
            iconView.image = appearance.linkPreviewAppearance.placeholderIcon
        }
    }
}
