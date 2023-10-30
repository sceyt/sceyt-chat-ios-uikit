//
//  ChannelProfileURICell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileURICell: TableViewCell {

    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
    
    open lazy var qrIconView = UIImageView()
        .withoutAutoresizingMask
    
    open lazy var uriLable = UILabel()
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelProfileVC.appearance {
        didSet {
            setupAppearance()
        }
    }

    open override func setup() {
        super.setup()
        iconView.image = .channelProfileURI
        qrIconView.image = .channelProfileQR
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        uriLable.textColor = appearance.uriColor
        uriLable.font = appearance.uriFont
    }
    
    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(iconView)
        contentView.addSubview(qrIconView)
        contentView.addSubview(uriLable)
        
        iconView.pin(to: contentView, anchors: [.leading(16), .top(10, .greaterThanOrEqual), .bottom(-10, .lessThanOrEqual), .centerY])
        qrIconView.pin(to: contentView, anchors: [.trailing(-16), .top(10, .greaterThanOrEqual), .bottom(-10, .lessThanOrEqual), .centerY])
        uriLable.pin(to: contentView, anchors: [.top(2, .greaterThanOrEqual), .bottom(-2, .lessThanOrEqual), .centerY])
        uriLable.leadingAnchor.pin(to: iconView.trailingAnchor, constant: 16)
        uriLable.trailingAnchor.pin(lessThanOrEqualTo: qrIconView.leadingAnchor, constant: -16)
    }
    
    open var data: String? {
        didSet {
            if let data {
                uriLable.text = Config.channelURIPrefix + data
            } else {
                uriLable.text = nil
            }
            
        }
    }
}
