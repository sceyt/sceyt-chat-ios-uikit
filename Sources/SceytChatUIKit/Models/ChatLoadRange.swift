//
//  ChatLoadRange.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 20.04.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

open class ChatLoadRange: Equatable {
    
    public let channelId: ChannelId
    public let startMessageId: MessageId
    public let endMessageId: MessageId
    public var channelLastMessageId: MessageId?
    
    public init(
        channelId: ChannelId,
        startMessageId: MessageId,
        endMessageId: MessageId
    ) {
        self.channelId = channelId
        self.startMessageId = startMessageId
        self.endMessageId = endMessageId
    }
    
    public init(dto: LoadRangeDTO) {
        channelId = ChannelId(dto.channelId)
        startMessageId = MessageId(dto.startMessageId)
        endMessageId = MessageId(dto.endMessageId)
    }
    
    public static func == (lhs: ChatLoadRange, rhs: ChatLoadRange) -> Bool {
        lhs.channelId == rhs.channelId &&
        lhs.startMessageId == rhs.startMessageId &&
        lhs.endMessageId == rhs.endMessageId
    }
}
