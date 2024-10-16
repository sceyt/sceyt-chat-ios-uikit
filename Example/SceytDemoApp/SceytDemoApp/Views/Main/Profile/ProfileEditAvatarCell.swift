//
//  ProfileEditAvatarCell.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class ProfileEditAvatarCell: TableViewCell {
    
    lazy var avatarButton: CircleButton = {
        $0.backgroundColor = .surface2
        $0.image = .chatActionCamera
        return $0.withoutAutoresizingMask
    }(CircleButton())
    
    override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarButton)
        
        avatarButton.pin(to: contentView, anchors: [.top(), .centerX(), .bottom()])
        avatarButton.resize(anchors: [.height(120), .width(120)])
    }
}
