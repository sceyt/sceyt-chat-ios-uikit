//
//  EditChannelViewController+AvatarCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelViewController.AvatarCell: AppearanceProviding {
    public static var appearance = Appearance(
        avatarBackgroundColor: .surface3,
        avatarPlaceholderIcon: .channelProfileEditAvatar
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var avatarBackgroundColor: UIColor
        
        @Trackable<Appearance, UIImage>
        public var avatarPlaceholderIcon: UIImage
        
        public init(
            avatarBackgroundColor: UIColor,
            avatarPlaceholderIcon: UIImage
        ) {
            self._avatarBackgroundColor = Trackable(value: avatarBackgroundColor)
            self._avatarPlaceholderIcon = Trackable(value: avatarPlaceholderIcon)
        }
        
        public init(
            reference: EditChannelViewController.AvatarCell.Appearance,
            avatarBackgroundColor: UIColor? = nil,
            avatarPlaceholderIcon: UIImage? = nil
        ) {
            self._avatarBackgroundColor = Trackable(reference: reference, referencePath: \.avatarBackgroundColor)
            self._avatarPlaceholderIcon = Trackable(reference: reference, referencePath: \.avatarPlaceholderIcon)
            
            if let avatarBackgroundColor { self.avatarBackgroundColor = avatarBackgroundColor }
            if let avatarPlaceholderIcon { self.avatarPlaceholderIcon = avatarPlaceholderIcon }
        }
    }
}
