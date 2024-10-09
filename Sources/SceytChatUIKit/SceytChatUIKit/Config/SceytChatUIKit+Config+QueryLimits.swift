//
//  SceytChatUIKit+Config+QueryLimits.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit.Config {
    public struct QueryLimits {
        public var channelListQueryLimit: UInt
        public var channelMemberListQueryLimit: UInt
        public var userListQueryLimit: UInt
        public var messageListQueryLimit: UInt
        public var attachmentListQueryLimit: UInt
        public var reactionListQueryLimit: UInt
        
        public init(
            channelListQueryLimit: UInt,
            channelMemberListQueryLimit: UInt,
            userListQueryLimit: UInt,
            messageListQueryLimit: UInt,
            attachmentListQueryLimit: UInt,
            reactionListQueryLimit: UInt
        ) {
            self.channelListQueryLimit = channelListQueryLimit
            self.channelMemberListQueryLimit = channelMemberListQueryLimit
            self.userListQueryLimit = userListQueryLimit
            self.messageListQueryLimit = messageListQueryLimit
            self.attachmentListQueryLimit = attachmentListQueryLimit
            self.reactionListQueryLimit = reactionListQueryLimit
        }
    }
}
