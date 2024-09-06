//
//  UserNameFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class UserNameFormatter: UserFormatting {
    
    public init() {}

    open func format(_ user: ChatUser) -> String {
        switch user.state {
        case .deleted:
            return L10n.User.deleted
        case .inactive:
            return L10n.User.inactive
        default:
            break
        }
        
        if user.id == me {
            return L10n.User.current
        }
        
        let displayName = [user.firstName, user.lastName]
            .compactMap { 
                let name = $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return name.isEmpty ? nil : name
            }
            .joined(separator: " ")
        
        if displayName.isEmpty {
            return user.id
        } else {
            return displayName
        }
    }

    open func short(_ user: ChatUser) -> String {
        if user.state != .active {
            return format(user)
        }

        if user.id == me {
            return L10n.User.current
        }

        let displayName = user.shortDisplayName

        if displayName.isEmpty {
            return user.id
        } else {
            return displayName
        }
    }
}

public extension ChatUser {
    var shortDisplayName: String {
        if let firstName, !firstName.isEmpty {
            return firstName
        }
        if let lastName, !lastName.isEmpty {
            return lastName
        }
        return ""
    }
}
