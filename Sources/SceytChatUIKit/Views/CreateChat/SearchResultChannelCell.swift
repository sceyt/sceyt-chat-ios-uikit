//
//  SearchResultChannelCell.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class SearchResultChannelCell: BaseChannelUserCell {
    
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
    
    open override func setupLayout() {
        super.setupLayout()
        
        avatarView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: Layouts.horizontalPadding)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = appearance.backgroundColor
        contentView.backgroundColor = appearance.backgroundColor
        separatorView.backgroundColor = appearance.separatorColor
        
        titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
        titleLabel.font = appearance.titleLabelAppearance.font
        statusLabel.textColor = appearance.subtitleLabelAppearance?.foregroundColor
        statusLabel.font = appearance.subtitleLabelAppearance?.font
    }
}
