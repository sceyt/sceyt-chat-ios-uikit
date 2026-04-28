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

    static var ftsBackfillVersionKey = "__SceytChatUIKit__ftsBackfillVersion__"
    /// Version of the FTS5 search index that has been built locally. When the
    /// running `MessageSearchStore.schemaVersion` is higher, the index is
    /// rebuilt from `MessageDTO`.
    static var ftsBackfillVersion: Int {
        get {
            SceytChatUIKit.shared.config.storageConfig.userDefaults.integer(forKey: ftsBackfillVersionKey)
        }
        set {
            SceytChatUIKit.shared.config.storageConfig.userDefaults.set(newValue, forKey: ftsBackfillVersionKey)
        }
    }
}
