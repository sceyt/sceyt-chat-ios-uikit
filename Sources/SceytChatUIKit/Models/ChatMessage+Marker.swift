//
//  ChatMessage+Marker.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 18.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData

extension ChatMessage {
    
    public struct Marker {
        public let messageId: MessageId
        public let createdAt: Date
        public let name: String
        public let user: ChatUser?
        
        public init(
            messageId: MessageId,
            createdAt: Date,
            name: String,
            user: ChatUser
        ) {
            self.messageId = messageId
            self.createdAt = createdAt
            self.name = name
            self.user = user
        }
        
        public init(dto: MarkerDTO) {
            messageId = MessageId(dto.messageId)
            createdAt = dto.createdAt.bridgeDate
            name = dto.name
            if let user = dto.user {
                self.user = .init(dto: user)
            } else {
                user = nil
            }
        }
        
        public init(marker: SceytChat.Marker) {
            messageId = marker.messageId
            name = marker.name
            createdAt = marker.createdAt
            user = .init(user: marker.user)
        }
    }
}

extension ChatMessage.Marker: Hashable {
    public static func == (lhs: ChatMessage.Marker, rhs: ChatMessage.Marker) -> Bool {
        lhs.messageId == rhs.messageId && lhs.name == rhs.name && lhs.user == rhs.user
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(messageId)
        hasher.combine(name)
        hasher.combine(user?.id)
    }
}
