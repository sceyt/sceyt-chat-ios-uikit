//
//  ChannelProfileNextItemCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileItemCell: TableViewCell {

    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
    
    open lazy var itemLable = UILabel()
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelProfileVC.appearance {
        didSet {
            setupAppearance()
        }
    }

    open override func setupAppearance() {
        super.setupAppearance()
        itemLable.textColor = appearance.itemColor
        itemLable.font = appearance.itemFont
    }
    
    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(iconView)
        contentView.addSubview(itemLable)
        
        iconView.pin(to: contentView, anchors: [.leading(16), .top(10, .greaterThanOrEqual), .bottom(-10, .lessThanOrEqual), .centerY])
        
        itemLable.pin(to: contentView, anchors: [.top(2, .greaterThanOrEqual), .bottom(-2, .lessThanOrEqual), .centerY])
        itemLable.leadingAnchor.pin(to: iconView.trailingAnchor, constant: 16)
        itemLable.trailingAnchor.pin(lessThanOrEqualTo: contentView.trailingAnchor, constant: 16)
    }
    
    open override var safeAreaInsets: UIEdgeInsets {
        .init(top: 0, left: 16, bottom: 0, right: 16)
    }
}
