//
//  SceytChatUIKit+Formatters.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

//    channelMessageBodyFormatter:Interface
//    messageBodyFormatter:Interface

//    messageDateFromatter:Interface
//    messageMarkerDateFormatter:Interface
//    messageShareDateFormatter:Interface // IOS only

extension SceytChatUIKit {
    public struct Formatters {
        public var userNameFormatter: any UserFormatting = UserNameFormatter()
        
        public var userPresenceDateFormatter: any UserPresenceFormatting = UserPresenceDateFormatter()
        
        public var channelDateFormatter: any DateFormatting = ChannelDateFormatter()
        
        public var channelNameFormatter: any ChannelFormatting = ChannelNameFormatter()
        
        public var channelUnreadCountFormatter: any UIntFormatting = ChannelUnreadCountFormatter()
        
        public var messageInfoDateFormatter: any DateFormatting = MessageInfoDateFormatter()
        
        public var messageViewCountFormatter: any UIntFormatting = MessageViewsCountFormatter()

        public var mediaDurationFormatter: any TimeIntervalFormatting = MediaDurationFormatter()
        
        public var fileSizeFormatter: any UIntFormatting = FileSizeFormatter()

        public var avatarInitialsFormatter: any StringFormatting = AvatarInitialsFormatter()
        
        public var messageDateSeparatorFormatter: any DateFormatting = MessageDateSeparatorFormatter()

        public var messageDateFormatter: any DateFormatting = MessageDateFormatter()
        
        public var channelInfoMediaDateFormatter: any DateFormatting = ChannelInfoMediaDateFormatter()

        public var channelProfileFileTimestamp: any DateFormatting = ChannelInfoMediaSeparatorDateFormatter()

        public var mediaPreviewDateFormatter: any DateFormatting = MediaPreviewDateFormatter()
        
        public var logDateFormatter: any DateFormatting = LogDateFormatter()
        
        public init() {}
    }
}
