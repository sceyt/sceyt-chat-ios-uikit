//
//  ChannelMemberAddCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelMemberAddCell: TableViewCell {

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
        iconView.pin(to: contentView, anchors: [.leading(16), .top(6, .greaterThanOrEqual), .bottom(-6, .lessThanOrEqual), .centerY])
        iconView.resize(anchors: [.height(40), .width(40)])
        titleLabel.pin(to: iconView, anchor: .centerY())
        titleLabel.leadingAnchor.pin(to: iconView.trailingAnchor, constant: 12)
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing()])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
        contentView.heightAnchor.pin(greaterThanOrEqualToConstant: 52)
    }
    
    open override func setup() {
        super.setup()
        iconView.image = Images.addMember
        titleLabel.textAlignment = .left
        titleLabel.text = L10n.Channel.Member.add
    }

    open override func setupAppearance() {
        super.setupAppearance()
        titleLabel.textColor = appearance.titleLabelTextColor
        titleLabel.font = appearance.titleLabelFont
        titleLabel.backgroundColor = .clear
        separatorView.backgroundColor = appearance.separatorColor
    }

}
