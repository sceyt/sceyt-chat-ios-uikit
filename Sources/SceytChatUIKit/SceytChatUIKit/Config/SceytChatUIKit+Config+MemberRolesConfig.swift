//
//  SceytChatUIKit+Config+PresenceConfig.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit.Config {
    public struct MemberRolesConfig {
        public let owner: String
        public let admin: String
        public let participant: String
        public let subscriber: String
        
        public init(
            owner: String,
            admin: String,
            participant: String,
            subscriber: String
        ) {
            self.owner = owner
            self.admin = admin
            self.participant = participant
            self.subscriber = subscriber
        }
    }
}
