//
//  SceytChatUIKit+Config+PresenceConfig.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit.Config {
    public struct IntervalOption {
        public let title: String
        public var timeInterval: TimeInterval
        
        public init(
            title: String,
            timeInterval: TimeInterval
        ) {
            self.title = title
            self.timeInterval = timeInterval
        }
    }
}
