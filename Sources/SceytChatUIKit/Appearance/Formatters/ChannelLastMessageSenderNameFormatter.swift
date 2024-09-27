//
//  ChannelLastMessageSenderNameFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class ChannelLastMessageSenderNameFormatter: ChannelFormatting {
    
    open func format(_ channel: ChatChannel) -> String {
        guard let user = channel.lastMessage?.user else { return "" }

        if channel.lastMessage?.state == .deleted || channel.isSelfChannel {
            // don't display sender
        } else if (user.id == me) || (user.id.isEmpty && channel.lastMessage?.incoming == false) {
            return "\(L10n.User.current): "
        } else if !channel.isDirect {
            return "\(SceytChatUIKit.shared.formatters.userShortNameFormatter.format(user)): "
        }
        
        return ""
    }
}
