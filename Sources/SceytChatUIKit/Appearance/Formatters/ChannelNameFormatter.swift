//
//  ChannelNameFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChannelNameFormatter: ChannelFormatting {
    
    public init() {}

    open func format( _ channel: ChatChannel) -> String {
        if !channel.isDirect {
            return channel.subject ?? ""
        }
        guard let peer = channel.peer
        else { return ""}
        switch peer.state {
        case .deleted:
            return L10n.Channel.Member.deleted
        case .inactive:
            return L10n.Channel.Member.inactive
        default:
            return SceytChatUIKit.shared.formatters.userNameFormatter.format(peer)
        }
    }
}
