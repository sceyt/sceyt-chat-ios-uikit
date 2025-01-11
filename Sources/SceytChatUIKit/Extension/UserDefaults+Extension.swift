//
//  UserDefaults+Extension.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 10.01.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import Foundation

extension UserDefaults {
    
    static var currentUserIdKey = "__SceytChatUIKit__currentUserIdKey__"
    static var currentUserId: String? {
        get {
            SceytChatUIKit.shared.config.storageConfig.userDefaults.object(forKey: currentUserIdKey) as? String
        }
        set {
            if let newValue, !newValue.isEmpty {
                SceytChatUIKit.shared.config.storageConfig.userDefaults.set(newValue, forKey: currentUserIdKey)
                return
            }
            
            SceytChatUIKit.shared.config.storageConfig.userDefaults.removeObject(forKey: currentUserIdKey)
        }
    }
}
