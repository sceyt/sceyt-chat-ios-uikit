//
//  UserDefaultAvatarProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct UserDefaultAvatarProvider: UserAvatarProviding {
    public func provideVisual(for user: ChatUser) -> AvatarRepresentation {
        switch user.state {
        case .active:   .image(.avatar)
        case .inactive: .image(.avatar)
        case .deleted:  .image(.deletedUser)
        }
    }
}

