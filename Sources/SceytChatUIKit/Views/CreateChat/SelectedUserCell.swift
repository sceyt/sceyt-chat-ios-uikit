//
//  SelectedUserCell.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class SelectedUserCell: SelectedBaseCell {
    open var userData: ChatUser! {
        didSet {
            
            label.text = appearance.titleFormatter.format(userData)
            presenceView.isHidden = userData.presence.state != .online
            avatarView.image = .deletedUser
            imageTask = appearance.avatarRenderer.render(
                userData,
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
        closeButton.setImage(appearance.removeIcon, for: .normal)
    }
}
