//
//  SceytChatUIKit+AvatarRenderers.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 29.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit {
    public struct AvatarRenderers {
        public var channelAvatarRenderer: any ChannelAvatarRendering = ChannelAvatarRenderer()
        public var userAvatarRenderer: any UserAvatarRendering = UserAvatarRenderer()
    }
}
