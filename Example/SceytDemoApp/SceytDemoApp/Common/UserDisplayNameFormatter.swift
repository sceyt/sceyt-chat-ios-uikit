//
//  UserDisplayNameFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.05.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChatUIKit

struct UserDisplayNameFormatter: UserFormatting {
    func format(_ user: ChatUser) -> String {
        switch user.state {
        case .deleted:
            return L10n.User.deleted
        case .inactive:
            return L10n.User.inactive
        default:
            break
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
