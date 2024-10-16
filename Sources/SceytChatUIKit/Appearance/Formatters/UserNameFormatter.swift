//
//  UserNameFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

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
}
