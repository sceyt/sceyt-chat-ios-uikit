//
//  ChannelProfileNextItemCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileItemCell: TableViewCell {

    open lazy var iconView = UIImageView()
    
    open lazy var titleLabel = UILabel()
    
    open lazy var detailLabel = UILabel()
    
    open lazy var row = UIStackView(row: [iconView, titleLabel, detailLabel], spacing: 16, alignment: .center)
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelProfileVC.appearance {
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
        
        row.pin(to: contentView, anchors: [.leading, .trailing, .top(ChannelProfileVC.Layouts.itemVerticalPadding), .bottom(-ChannelProfileVC.Layouts.itemVerticalPadding)])
        iconView.resize(anchors: [.height(ChannelProfileVC.Layouts.itemIconSize), .width(ChannelProfileVC.Layouts.itemIconSize)])
    }
    
    open override var safeAreaInsets: UIEdgeInsets {
        .init(top: 0, left: 2 * ChannelProfileVC.Layouts.cellHorizontalPadding,
              bottom: 0, right:  2 * ChannelProfileVC.Layouts.cellHorizontalPadding)
    }
}
