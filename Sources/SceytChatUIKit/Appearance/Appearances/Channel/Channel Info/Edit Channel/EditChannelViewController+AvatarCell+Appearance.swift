//
//  EditChannelViewController+AvatarCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelViewController.AvatarCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var avatarBackgroundColor: UIColor = .surface3
        public var avatarPlaceholderIcon: UIImage = .channelProfileEditAvatar
        
        public init(
            avatarBackgroundColor: UIColor = .surface3,
            avatarPlaceholderIcon: UIImage = .channelProfileEditAvatar
        ) {
            self.avatarBackgroundColor = avatarBackgroundColor
            self.avatarPlaceholderIcon = avatarPlaceholderIcon
        }
    }
}
