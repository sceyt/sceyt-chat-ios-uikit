//
//  ChannelProfileEditVM.swift
//  SceytChatUIKit
//

import Foundation

import SceytChat

open class ChannelProfileEditVM: NSObject {
    
    public private(set) var provider: ChannelProvider
    public private(set) var channel: ChatChannel
    
    public required init(channel: ChatChannel) {
        self.channel = channel
        provider = ChannelProvider
            .init(channelId: channel.id)
        super.init()
    }
    
    var canShowURI: Bool {
        channel.type == .public
    }
}
