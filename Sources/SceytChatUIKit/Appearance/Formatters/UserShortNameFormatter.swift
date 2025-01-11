//
//  UserShortNameFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class UserShortNameFormatter: UserFormatting {

    open func format(_ user: ChatUser) -> String {
        if user.state != .active {
            return SceytChatUIKit.shared.formatters.userNameFormatter.format(user)
        }

        if user.id == SceytChatUIKit.shared.currentUserId {
            return L10n.User.current
        }

        let displayName = if let firstName = user.firstName, !firstName.isEmpty {
            firstName
        } else if let lastName = user.lastName, !lastName.isEmpty {
            lastName
        } else {
            ""
        }
        
        if displayName.isEmpty {
            return user.id
        } else {
            return displayName
        }
    }
}
