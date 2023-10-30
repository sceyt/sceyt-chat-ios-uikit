//
//  ChannelDisplayNameFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

public protocol ChannelDisplayNameFormatter {

    func format( _ channel: ChatChannel) -> String

}

open class DefaultChannelDisplayNameFormatter: ChannelDisplayNameFormatter {
    
    public init() {}

    open func format( _ channel: ChatChannel) -> String {
        if channel.isGroup {
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
            return Formatters.userDisplayName.format(peer)
        }

    }
}
