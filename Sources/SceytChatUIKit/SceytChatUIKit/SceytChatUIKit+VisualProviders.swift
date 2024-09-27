//
//  SceytChatUIKit+VisualProviders.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.09.24.
//

import UIKit

extension SceytChatUIKit {
    public struct VisualProviders {
        
        public var userAvatarProvider: any UserAvatarProviding = UserDefaultAvatarProvider()
        public var channelAvatarProvider: any ChannelAvatarProviding = ChannelDefaultAvatarProvider()
        public var channelURIValidationMessageProvider: any ChannelURIValidationMessageProviding = ChannelURIValidationMessageProvider()
        public var attachmentIconProvider: any AttachmentIconProviding = AttachmentIconProvider()
        public var channelListAttachmentIconProvider: any AttachmentIconProviding = ChannelListAttachmentIconProvider()
        public var connectionStateProvider: any ConnectionStateProviding = ConnectionStateTextProvider()
        public var presenceStateIconProvider: any PresenceStateIconProviding = PresenceStateIconProvider()
    }
}
