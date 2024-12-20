//
//  SceytChatUIKit+VisualProviders.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.09.24.
//

import Foundation

extension SceytChatUIKit {
    public struct VisualProviders {
        
        public var userAvatarProvider: any UserAvatarProviding = UserDefaultAvatarProvider()
        public var channelDefaultAvatarProvider: any ChannelAvatarProviding = ChannelDefaultAvatarProvider()
        public var channelURIValidationMessageProvider: any ChannelURIValidationMessageProviding = ChannelURIValidationMessageProvider()
        public var senderNameColorProvider: any UserColorProviding = SenderNameColorProvider()
        public var attachmentIconProvider: any AttachmentIconProviding = AttachmentIconProvider()
        public var channelListAttachmentIconProvider: any AttachmentIconProviding = ChannelListAttachmentIconProvider()
        public var connectionStateProvider: any ConnectionStateProviding = ConnectionStateTextProvider()
        public var presenceStateIconProvider: any PresenceStateIconProviding = PresenceStateIconProvider()
        public var defaultMarkerTitleProvider: any DefaultMarkerTitleProviding = DefaultMarkerTitleProvider()
    }
}
