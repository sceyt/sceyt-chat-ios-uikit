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
        public var enableDatabase: Bool
        public let databaseFilename: String
        public var databaseFileDirectory: URL?
        public var userDefaults: UserDefaults
        
        public init(
            storageDirectory: URL? = {
                if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            return URL(fileURLWithPath: path)
        }
                return nil
            }(),
            dataModelName: String = "SceytChatModel",
            enableDatabase: Bool = true,
            databaseFilename: String = "chatdb",
            databaseFileDirectory: URL? = {
                if let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first {
            return URL(fileURLWithPath: path)
        }
                return nil
            }(),
            userDefaults: UserDefaults = .standard
        ) {
            self.storageDirectory = storageDirectory
            self.dataModelName = dataModelName
            self.enableDatabase = enableDatabase
            self.databaseFilename = databaseFilename
            self.databaseFileDirectory = databaseFileDirectory
            self.userDefaults = userDefaults
        }
    }
}
