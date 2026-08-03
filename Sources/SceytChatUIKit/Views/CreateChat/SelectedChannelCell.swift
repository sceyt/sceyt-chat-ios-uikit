//
//  SelectedChannelCell.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class SelectedChannelCell: SelectedBaseCell {
    open var channelData: ChatChannel! {
        didSet {
            label.text = appearance.titleFormatter.format(channelData)
            presenceView.isHidden = channelData.peer?.presence.state != .online
            imageTask = appearance.avatarRenderer.render(
                channelData,
                with: appearance.avatarAppearance,
                into: avatarView
            )
        }
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = appearance.backgroundColor
        label.font = appearance.labelAppearance.font
        label.textColor = appearance.labelAppearance.foregroundColor
        label.lineBreakMode = .byTruncatingTail
        closeButton.setImage(appearance.removeIcon, for: .normal)
    }
}
