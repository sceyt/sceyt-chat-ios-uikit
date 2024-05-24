//
//  UserDisplayNameFormatter.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 24.05.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChatUIKit

class UserDisplayNameFormatter: DefaultUserDisplayNameFormatter {
    override func format(_ user: ChatUser) -> String {
        switch user.state {
        case .deleted, .inactive:
            return super.format(user)
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
