//
//  ChannelAvatarVM.swift
//  SceytChatUIKit
//
//  Created by Duc on 24/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class ChannelAvatarVM {
    public required init(channel: ChatChannel) {
        self.channel = channel
    }

    open var channel: ChatChannel
}
