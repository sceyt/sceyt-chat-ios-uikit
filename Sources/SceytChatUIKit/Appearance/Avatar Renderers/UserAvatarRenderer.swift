//
//  UserAvatarRenderer.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 29.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public struct UserAvatarRenderer: UserAvatarRendering {
    
    public init() {}
    
    public func render(
        _ user: ChatUser,
        with appearance: AvatarAppearance,
        into imagePresentable: ImagePresentable
    ) -> Cancellable? {
        let avatarRepresentation = SceytChatUIKit.shared.visualProviders.userAvatarProvider.provideVisual(for: user)
        
        if let view = imagePresentable as? UIView {
            view.backgroundColor = appearance.backgroundColor
            view.clipsToBounds = true
            view.contentMode = .scaleAspectFill
            
            imagePresentable.shape = appearance.shape
        }
        
        return switch avatarRepresentation {
        case .image(let image):
            Components.avatarBuilder.loadAvatar(
                into: imagePresentable,
                for: user,
                defaultImage: image
            )
        case .initialsAppearance(let initialsAppearance):
            Components.avatarBuilder.loadAvatar(
                into: imagePresentable,
                for: user,
                appearance: initialsAppearance
            )
        }
    }
}
