//
//  ChannelDisplayNameFormatter.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

public protocol ChannelDisplayNameFormatter {

    func format( _ channel: ChatChannel) -> String

}

open class DefaultChannelDisplayNameFormatter: ChannelDisplayNameFormatter {
    
    public init() {}

    open func format( _ channel: ChatChannel) -> String {
        if channel.type == .public || channel.type == .private {
            return channel.subject ?? ""
        }
        guard let peer = channel.peer else { return ""}
        switch peer.activityState {
        case .deleted:
            return L10n.Channel.Member.deleted
        case .inactive:
            return L10n.Channel.Member.inactive
        default:
            return DefaultUserDisplayNameFormatter().format(peer)
        }

    }
}
