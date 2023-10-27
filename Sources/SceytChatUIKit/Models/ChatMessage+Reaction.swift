//
//  ChatMessage+Reaction.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 18.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

import SceytChat
import CoreData

extension ChatMessage {
    
    public class Reaction {
        public let id: ReactionId
        public let messageId: MessageId
        public let key: String
        public let score: UInt
        public let reason: String?
        public let createdAt: Date
        public let user: ChatUser?
        public internal(set) var message: ChatMessage?
        
        public init(
            id: ReactionId,
            messageId: MessageId,
            key: String,
            score: UInt,
            reason: String? = nil,
            updatedAt: Date = Date(),
            user: ChatUser? = nil
        ) {
            self.id = id
            self.messageId = messageId
            self.key = key
            self.score = score
            self.reason = reason
            self.createdAt = updatedAt
            self.user = user
        }
        
        public init(dto: ReactionDTO, convertMessage: Bool = false) {
            id = UInt64(dto.id)
            messageId = MessageId(dto.messageId)
            key = dto.key
            score = UInt(dto.score)
            reason = dto.reason
            createdAt = dto.createdAt?.bridgeDate ?? Date()
            if let user = dto.user {
                self.user = .init(dto: user)
            } else {
                self.user = ChatUser(id: "")
            }
            if convertMessage, let message = dto.message {
                self.message = ChatMessage(dto: message)
            }
        }
        
        public init(reaction: SceytChat.Reaction) {
            id = reaction.id
            messageId = reaction.messageId
            key = reaction.key
            score = UInt(reaction.score)
            reason = reaction.reason
            createdAt = reaction.createdAt
            user = ChatUser(user: reaction.user)
        }
    }
    
    public struct ReactionTotal {
        public let key: String
        public let score: UInt
        public let count: UInt
        
        public init(
            key: String,
            score: UInt,
            count: UInt
        ) {
            self.key = key
            self.score = score
            self.count = count
        }
        
        public init(dto: ReactionTotalDTO) {
            key = dto.key
            score = UInt(dto.score)
            count = UInt(dto.count)
        }
        
        public init(reaction: SceytChat.ReactionTotal) {
            key = reaction.key
            score = reaction.score
            count = reaction.count
        }
    }
}


extension ChatMessage.Reaction: Hashable {
    
    public static func == (lhs: ChatMessage.Reaction, rhs: ChatMessage.Reaction) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
