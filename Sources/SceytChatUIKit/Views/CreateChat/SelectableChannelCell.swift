//
//  SelectableChannelCell.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class SelectableChannelCell: BaseChannelUserCell {
    
    open lazy var checkBoxView = Components.checkBoxView.init()
        .withoutAutoresizingMask
    
    open var channelData: ChatChannel! {
        didSet {
            imageTask = appearance.avatarRenderer.render(
                channelData,
                with: appearance.avatarAppearance,
                into: avatarView
            )
            
            titleLabel.text = appearance.titleFormatter.format(channelData)
            statusLabel.text = appearance.subtitleFormatter.format(channelData)
        }
    }
    
    override open func setup() {
        super.setup()
        
        checkBoxView.isUserInteractionEnabled = false
        selectionStyle = .none
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(checkBoxView)
        
        checkBoxView.pin(to: contentView, anchors: [.leading(6), .centerY()])
        checkBoxView.resize(anchors: [.width(44), .height(44)])
        avatarView.leadingAnchor.pin(to: checkBoxView.trailingAnchor, constant: 2)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        checkBoxView.parentAppearance = appearance.checkBoxAppearance
        
        backgroundColor = appearance.backgroundColor
        contentView.backgroundColor = appearance.backgroundColor
        separatorView.backgroundColor = appearance.separatorColor
        
        titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
        titleLabel.font = appearance.titleLabelAppearance.font
        statusLabel.textColor = appearance.subtitleLabelAppearance?.foregroundColor
        statusLabel.font = appearance.subtitleLabelAppearance?.font
    }
}
