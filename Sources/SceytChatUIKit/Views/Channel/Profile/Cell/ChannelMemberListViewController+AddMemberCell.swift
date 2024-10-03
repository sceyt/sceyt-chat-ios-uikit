//
//  ChannelMemberListViewController+AddMemberCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelMemberListViewController {
    open class AddMemberCell: TableViewCell {
        
        open lazy var iconView = Components.circleImageView
            .init()
            .contentMode(.center)
            .withoutAutoresizingMask
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(iconView)
            contentView.addSubview(titleLabel)
            contentView.addSubview(separatorView)
            iconView.pin(to: contentView, anchors: [.leading(16), .top(8, .greaterThanOrEqual), .centerY])
            iconView.resize(anchors: [.height(40), .width(40)])
            titleLabel.pin(to: iconView, anchor: .centerY())
            titleLabel.leadingAnchor.pin(to: iconView.trailingAnchor, constant: 12)
            separatorView.pin(to: contentView, anchors: [.bottom, .trailing(-16)])
            separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
            separatorView.heightAnchor.pin(constant: 1)
            contentView.heightAnchor.pin(greaterThanOrEqualToConstant: 56)
        }
        
        open override func setup() {
            super.setup()
            titleLabel.textAlignment = .left
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            iconView.image = appearance.addIcon
            titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
            titleLabel.font = appearance.titleLabelAppearance.font
            titleLabel.backgroundColor = appearance.titleLabelAppearance.backgroundColor
            separatorView.backgroundColor = appearance.separatorColor
        }
    }
}
