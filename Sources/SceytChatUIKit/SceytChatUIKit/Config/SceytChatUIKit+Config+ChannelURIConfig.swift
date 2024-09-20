//
//  SceytChatUIKit+Config+PresenceConfig.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit.Config {
    public struct ChannelURIConfig {
        public let prefix: String
        public let minLength: Int
        public let maxLength: Int
        public let regex: String
    }
}
