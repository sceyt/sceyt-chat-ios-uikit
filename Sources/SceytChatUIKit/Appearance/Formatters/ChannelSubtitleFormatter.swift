//
//  ChannelSubtitleFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//


import Foundation
import SceytChat

open class ChannelSubtitleFormatter: ChannelFormatting {
    
    public init() {}
    
    open func format( _ channel: ChatChannel) -> String {
        let memberCount = Int(channel.memberCount)
        var text = ""
        switch channel.channelType {
        case .broadcast:
            switch channel.memberCount {
            case 1:
                text = L10n.Channel.SubscriberCount.one
            case 2...:
                text = L10n.Channel.SubscriberCount.more(memberCount)
            default:
                text = ""
            }
        case .group:
            switch channel.memberCount {
            case 1:
                text = L10n.Channel.MembersCount.one
            case 2...:
                text = L10n.Channel.MembersCount.more(memberCount)
            default:
                text = ""
            }
        case .direct:
            if let peer = channel.peer {
                text = SceytChatUIKit.shared.formatters.userPresenceDateFormatter.format(peer)
            } else {
                text = ""
            }
        }
        
        return text
    }
}
