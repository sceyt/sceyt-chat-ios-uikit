//
//  SceytChatUIKit+Config+PresenceConfig.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit.Config {
    public struct ChannelTypesConfig {
        public let direct: String
        public let group: String
        public let broadcast: String
        
        public init(
            direct: String,
            group: String,
            broadcast: String
        ) {
            self.direct = direct
            self.group = group
            self.broadcast = broadcast
        }
    }
}
