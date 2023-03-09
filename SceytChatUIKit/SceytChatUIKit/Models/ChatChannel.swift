//
//  ChatChannel.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat
import CoreData

public struct ChatChannel {
    public var id: ChannelId
    public var type: ChannelType
    public var createdAt: Date
    public var updatedAt: Date?
    public var unreadMessageCount: UInt64
    public var unreadMentionCount: UInt64
    public var unreadReactionCount: UInt64
    public var lastDisplayedMessageId: MessageId
    public var lastReceivedMessageId: MessageId
    public var memberCount: Int64
    public var markedAsUnread: Bool
    public var muted: Bool
    public var muteExpireDate: Date?
    public var subject: String?
    public var label: String?
    public var metadata: String?
    public var avatarUrl: URL?
    public var uri: String?
    public var lastMessage: ChatMessage?
    public var peer: ChatUser?
    public var roleName: String?
    public var draftMessage: NSAttributedString?
    
    public var decodedMetadata: Metadata?
    
    init(id: ChannelId,
         type: ChatChannel.ChannelType,
         createdAt: Date = Date(),
         updatedAt: Date? = nil,
         unreadMessageCount: UInt64 = 0,
         unreadMentionCount: UInt64 = 0,
         unreadReactionCount: UInt64 = 0,
         lastDisplayedMessageId: MessageId = 0,
         lastReceivedMessageId: MessageId = 0,
         memberCount: Int64 = 0,
         markedAsUnread: Bool = false,
         muted: Bool = false,
         muteExpireDate: Date? = nil,
         subject: String? = nil,
         label: String? = nil,
         metadata: String? = nil,
         avatarUrl: URL? = nil,
         uri: String? = nil,
         lastMessage: ChatMessage? = nil,
         peer: ChatUser? = nil,
         roleName: String? = nil,
         draftMessage: NSAttributedString? = nil) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.unreadMessageCount = unreadMessageCount
        self.unreadMentionCount = unreadMentionCount
        self.unreadReactionCount = unreadReactionCount
        self.lastDisplayedMessageId = lastDisplayedMessageId
        self.lastReceivedMessageId = lastReceivedMessageId
        self.memberCount = memberCount
        self.markedAsUnread = markedAsUnread
        self.muted = muted
        self.muteExpireDate = muteExpireDate
        self.subject = subject
        self.label = label
        self.metadata = metadata
        self.avatarUrl = avatarUrl
        self.uri = uri
        self.lastMessage = lastMessage
        self.peer = peer
        self.roleName = roleName
        self.draftMessage = draftMessage
        if let metadata {
            decodedMetadata = try? Metadata.decode(metadata)
        }
    }
    
    public init(dto: ChannelDTO) {
        self.init(
            id: ChannelId(dto.id),
            type: ChannelType(rawValue: dto.type)!,
            createdAt: dto.createdAt.bridgeDate,
            updatedAt: dto.updatedAt?.bridgeDate,
            unreadMessageCount: UInt64(dto.unreadMessageCount),
            unreadMentionCount: UInt64(dto.unreadMentionCount),
            unreadReactionCount: UInt64(dto.unreadReactionCount),
            lastDisplayedMessageId: MessageId(dto.lastDisplayedMessageId),
            lastReceivedMessageId: MessageId(dto.lastReceivedMessageId),
            memberCount: dto.memberCount,
            markedAsUnread: dto.markedAsUnread,
            muted: dto.muted,
            muteExpireDate: dto.muteExpireDate?.bridgeDate,
            subject: dto.subject,
            label: dto.label,
            metadata: dto.metadata,
            avatarUrl: dto.avatarUrl,
            uri: dto.uri,
            lastMessage: dto.lastMessage == nil ? nil : .init(dto: dto.lastMessage!),
            peer: dto.peer == nil ? nil : .init(dto: dto.peer!),
            roleName: dto.currentUserRole?.name,
            draftMessage: dto.draft
        )
    }
    
    public init(channel: Channel) {
        let type: ChannelType
        var user: ChatUser?
        switch channel {
        case is PublicChannel:
            type = .public
        case is PrivateChannel:
            type = .private
        default:
            type = .direct
            if let peer = (channel as? DirectChannel)?.peer {
                user = .init(user: peer)
            }
        }
        
        self.init(
            id: channel.id,
            type: type,
            createdAt: channel.createdAt,
            updatedAt: channel.updatedAt,
            unreadMessageCount: UInt64(channel.unreadMessageCount),
            unreadMentionCount: UInt64(channel.unreadMentionCount),
            unreadReactionCount: UInt64(channel.unreadReactionCount),
            lastDisplayedMessageId: channel.lastDisplayedMessageId,
            lastReceivedMessageId: channel.lastReceivedMessageId,
            memberCount: Int64(channel.memberCount),
            markedAsUnread: channel.markedAsUnread,
            muted: channel.muted,
            muteExpireDate: channel.muteExpireDate,
            subject: (channel as? GroupChannel)?.subject,
            label: (channel as? GroupChannel)?.label,
            metadata: (channel as? GroupChannel)?.metadata,
            avatarUrl: (channel as? GroupChannel)?.avatarUrl,
            uri: (channel as? PublicChannel)?.uri,
            lastMessage: channel.lastMessage.map { ChatMessage(message: $0, channelId: channel.id)},
            peer: user,
            roleName: (channel as? GroupChannel)?.role)
    }
}

public extension ChatChannel {
    
    @frozen
    enum ChannelType: Int16 {
        case direct
        case `private`
        case `public`
        
        public var isGroup: Bool {
            self != .direct
        }
    }
}

extension ChatChannel {
    
    public struct Metadata: Codable {
        
        public var description: String

        enum CodingKeys: String, CodingKey {
            case description = "d"
        }
        
        public init(description: String = "") {
            self.description = description
        }
        
        func build() -> String? {
            try? jsonString()
        }
        
        static func decode(_ value: String) throws -> Metadata {
           try JSONDecoder()
                .decode(
                    Metadata.self,
                    from: value.data(using: .utf8) ?? Data()
                )
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            description = (try? container.decode(String.self, forKey: CodingKeys.description)) ?? ""
        }
    }
}
