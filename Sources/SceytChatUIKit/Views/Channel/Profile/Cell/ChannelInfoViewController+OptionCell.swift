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
        
        open lazy var detailLabel = UILabel()
        
        open lazy var row = UIStackView(row: [iconView, titleLabel, detailLabel], spacing: 16, alignment: .center)
            .withoutAutoresizingMask
        
        public lazy var appearance = Components.channelInfoViewController.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.cellBackgroundColor
            titleLabel.textColor = appearance.itemColor
            titleLabel.font = appearance.itemFont
            detailLabel.textColor = appearance.detailColor
            detailLabel.font = appearance.detailFont
        }
        
        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(row)
            
            row.pin(to: contentView, anchors: [.leading, .trailing, .top(Components.channelInfoViewController.Layouts.itemVerticalPadding), .bottom(-Components.channelInfoViewController.Layouts.itemVerticalPadding)])
            iconView.resize(anchors: [.height(Components.channelInfoViewController.Layouts.itemIconSize), .width(Components.channelInfoViewController.Layouts.itemIconSize)])
        }
        
        open override var safeAreaInsets: UIEdgeInsets {
            .init(top: 0, left: 2 * Components.channelInfoViewController.Layouts.cellHorizontalPadding,
                  bottom: 0, right:  2 * Components.channelInfoViewController.Layouts.cellHorizontalPadding)
        }
    }
}
