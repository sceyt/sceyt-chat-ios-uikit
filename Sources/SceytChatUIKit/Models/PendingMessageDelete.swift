//
//  PendingMessageDelete.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// Context-free snapshot of a `PendingMessageDeleteDTO`, safe to pass between queues.
public struct PendingMessageDelete {
    public let messageTid: Int64
    public let channelId: ChannelId
    /// 0 while the message has no known server id.
    public let messageId: MessageId
    public let type: DeleteMessageType
    public let createdAt: Int64
    public let lastAttemptAt: Int64
    public let retryCount: Int
}

// MARK: - init with DTO

extension PendingMessageDelete {
    init(dto: PendingMessageDeleteDTO) {
        self.messageTid = dto.messageTid
        self.channelId = ChannelId(dto.channelId)
        self.messageId = MessageId(dto.messageId)
        self.type = dto.type
        self.createdAt = dto.createdAt
        self.lastAttemptAt = dto.lastAttemptAt
        self.retryCount = Int(dto.retryCount)
    }
}
