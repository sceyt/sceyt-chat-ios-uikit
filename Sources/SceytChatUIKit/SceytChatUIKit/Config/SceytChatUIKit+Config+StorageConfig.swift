//
//  SceytChatUIKit+Config+PresenceConfig.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit.Config {
    public struct StorageConfig {
        public var storageDirectory: URL?
        public let dataModelName: String
        public let databaseFilename: String
        public var databaseFileDirectory: URL?
        public var userDefaults: UserDefaults
    }
}
