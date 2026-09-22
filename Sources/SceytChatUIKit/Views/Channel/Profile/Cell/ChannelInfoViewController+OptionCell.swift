//
//  ChannelInfoViewController+OptionCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class OptionCell: TableViewCell {
        
        open lazy var iconView = UIImageView()
        
        open lazy var titleLabel = UILabel()
        
        open lazy var descriptionLabel = UILabel()

        open lazy var textVStack = UIStackView(column: [titleLabel, descriptionLabel], spacing: 4)

        open lazy var detailLabel = UILabel()

        open lazy var row = UIStackView(row: [iconView, textVStack, detailLabel], spacing: 16, alignment: .center)
            .withoutAutoresizingMask
                
        open override func prepareForReuse() {
            super.prepareForReuse()
            titleLabel.text = nil
            descriptionLabel.text = nil
            detailLabel.text = nil
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
            titleLabel.font = appearance.titleLabelAppearance.font
            descriptionLabel.textColor = appearance.descriptionLabelAppearance?.foregroundColor
            descriptionLabel.font = appearance.descriptionLabelAppearance?.font
            descriptionLabel.numberOfLines = 0
            detailLabel.textAlignment = .right
            detailLabel.textColor = appearance.descriptionLabelAppearance?.foregroundColor
            detailLabel.font = appearance.descriptionLabelAppearance?.font
        }
        
        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(row)

            row.pin(to: contentView, anchors: [.leading, .trailing, .top(Components.channelInfoViewController.Layouts.itemVerticalPadding), .bottom(-Components.channelInfoViewController.Layouts.itemVerticalPadding)])
            iconView.resize(anchors: [.height(Components.channelInfoViewController.Layouts.itemIconSize), .width(Components.channelInfoViewController.Layouts.itemIconSize)])

            // The labels share one identifier across every option row; UI tests
            // scope them to a specific row via the enclosing cell's identifier.
            typealias AID = SceytChatUIKit.AccessibilityIdentifiers.ChannelInfo.Option
            titleLabel.accessibilityIdentifier = AID.title
            detailLabel.accessibilityIdentifier = AID.detail
            descriptionLabel.accessibilityIdentifier = AID.description
        }
        
        open override var safeAreaInsets: UIEdgeInsets {
            .init(top: 0, left: 2 * Components.channelInfoViewController.Layouts.cellHorizontalPadding,
                  bottom: 0, right:  2 * Components.channelInfoViewController.Layouts.cellHorizontalPadding)
        }
    }
}
