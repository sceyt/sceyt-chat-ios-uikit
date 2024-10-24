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
            label.text = SceytChatUIKit.shared.formatters.userShortNameFormatter.format(userData)
            presenceView.isHidden = userData.presence.state != .online
            avatarView.imageView.image = .deletedUser
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView, for: userData)
        }
    }
}
