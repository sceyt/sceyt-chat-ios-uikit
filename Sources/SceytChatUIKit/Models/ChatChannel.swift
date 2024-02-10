//
//  ChatChannel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData

public class ChatChannel {
    public let id: ChannelId
    public let parentChannelId: ChannelId
    public let uri: String
    public let type: String
    public let createdAt: Date
    public let updatedAt: Date?
    public let newMessageCount: UInt64
    public let newMentionCount: UInt64
    public let newReactionMessageCount: UInt64
    public let lastDisplayedMessageId: MessageId
    public let lastReceivedMessageId: MessageId
    public let memberCount: Int64
    public let unread: Bool
    public let hidden: Bool
    public let archived: Bool
    public let muted: Bool
    public let muteTill: Date?
    public let pinnedAt: Date?
    public let subject: String?
    public let metadata: String?
    public let avatarUrl: String?
    public let lastMessage: ChatMessage?
    public let lastReaction: ChatMessage.Reaction?
    public let userRole: String?
    public var unSynched: Bool = false
    
    public var draftMessage: NSAttributedString?
    
    public var decodedMetadata: Metadata?
    
    public static var shouldCreateMembersObserver = true
    
    /// available only if channel type is direct
    public private(set) var members: [ChatChannelMember]?
    
    public init(
        id: ChannelId,
        parentChannelId: ChannelId = 0,
        type: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        newMessageCount: UInt64 = 0,
        newMentionCount: UInt64 = 0,
        newReactionMessageCount: UInt64 = 0,
        lastDisplayedMessageId: MessageId = 0,
        lastReceivedMessageId: MessageId = 0,
        memberCount: Int64 = 0,
        unread: Bool = false,
        hidden: Bool = false,
        archived: Bool = false,
        muted: Bool = false,
        muteTill: Date? = nil,
        pinnedAt: Date? = nil,
        subject: String? = nil,
        metadata: String? = nil,
        avatarUrl: String? = nil,
        uri: String,
        lastMessage: ChatMessage? = nil,
        lastReaction: ChatMessage.Reaction? = nil,
        members: [ChatChannelMember]? = nil,
        userRole: String? = nil,
        draftMessage: NSAttributedString? = nil,
        unSynched: Bool = false
    ) {
        self.id = id
        self.parentChannelId = parentChannelId
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.newMessageCount = newMessageCount
        self.newMentionCount = newMentionCount
        self.newReactionMessageCount = newReactionMessageCount
        self.lastDisplayedMessageId = lastDisplayedMessageId
        self.lastReceivedMessageId = lastReceivedMessageId
        self.memberCount = memberCount
        self.unread = unread
        self.hidden = hidden
        self.archived = archived
        self.muted = muted
        self.muteTill = muteTill
        self.pinnedAt = pinnedAt
        self.subject = subject
        self.metadata = metadata
        self.avatarUrl = avatarUrl
        self.uri = uri
        self.lastMessage = lastMessage
        self.lastReaction = lastReaction
        self.userRole = userRole
        self.draftMessage = draftMessage
        self.unSynched = unSynched
        if let metadata {
            decodedMetadata = try? Metadata.decode(metadata)
        }
        if let members {
            self.members = members
            if Self.shouldCreateMembersObserver {
                createMembersObserver()
            }
        }
    }
    
    public convenience init(dto: ChannelDTO) {
        self.init(
            id: ChannelId(dto.id),
            parentChannelId: ChannelId(dto.parentChannelId),
            type: dto.type,
            createdAt: dto.createdAt.bridgeDate,
            updatedAt: dto.updatedAt?.bridgeDate,
            newMessageCount: UInt64(dto.newMessageCount),
            newMentionCount: UInt64(dto.newMentionCount),
            newReactionMessageCount: UInt64(dto.newReactionMessageCount),
            lastDisplayedMessageId: MessageId(dto.lastDisplayedMessageId),
            lastReceivedMessageId: MessageId(dto.lastReceivedMessageId),
            memberCount: dto.memberCount,
            unread: dto.unread,
            hidden: dto.hidden,
            archived: dto.archived,
            muted: dto.muted,
            muteTill: dto.muteTill?.bridgeDate,
            pinnedAt: dto.pinnedAt?.bridgeDate,
            subject: dto.subject,
            metadata: dto.metadata,
            avatarUrl: dto.avatarUrl,
            uri: dto.uri ?? "",
            lastMessage: dto.lastMessage == nil ? nil : .init(dto: dto.lastMessage!),
            lastReaction: dto.lastReaction == nil ? nil : .init(dto: dto.lastReaction!, convertMessage: true),
            userRole: dto.userRole?.name,
            draftMessage: dto.draft,
            unSynched: dto.unsynched
        )
        if self.channelType == .direct {
            if let context = dto.managedObjectContext {
                members = MemberDTO.fetch(channelId: ChannelId(dto.id), context: context).map { $0.convert() }
            } else {
                #if DEBUG
                fatalError("ChannelDTO managedObjectContext is nil")
                #endif
            }
            if Self.shouldCreateMembersObserver {
                createMembersObserver()
            }
        }
    }
    
    public convenience init(channel: Channel) {
        self.init(
            id: channel.id,
            parentChannelId: channel.parentChannelId,
            type: channel.type,
            createdAt: channel.createdAt,
            updatedAt: channel.updatedAt,
            newMessageCount: UInt64(channel.newMessageCount),
            newMentionCount: UInt64(channel.newMentionCount),
            newReactionMessageCount: UInt64(channel.newReactionMessageCount),
            lastDisplayedMessageId: channel.lastDisplayedMessageId,
            lastReceivedMessageId: channel.lastReceivedMessageId,
            memberCount: Int64(channel.memberCount),
            unread: channel.unread,
            hidden: channel.hidden,
            archived: channel.archived,
            muted: channel.muted,
            muteTill: channel.muteTill,
            pinnedAt: channel.pinnedAt,
            subject: channel.subject,
            metadata: channel.metadata,
            avatarUrl: channel.avatarUrl,
            uri: channel.uri,
            lastMessage: channel.lastMessage.map { ChatMessage(message: $0, channelId: channel.id)},
            lastReaction: channel.lastReactions?.max(by: { $0.id > $1.id }).map { ChatMessage.Reaction(reaction: $0)},
            userRole: channel.userRole)
        if self.channelType == .direct {
            members = channel.members?.map { .init(member: $0)}
            if Self.shouldCreateMembersObserver {
                createMembersObserver()
            }
        }
    }
    
    deinit {
        try? memberObserver?.stopObserver()
    }
    fileprivate var memberObserver: LazyDatabaseObserver<MemberDTO, ChatChannelMember>?
    
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

public extension ChatChannel {
    
    enum ChannelType: String {
        case direct, broadcast, `private`
    }
    
    var channelType: ChannelType {
        switch type {
        case Config.directChannel:
            return .direct
        case Config.broadcastChannel:
            return .broadcast
        default:
            return .private
        }
    }
    
    var isGroup: Bool {
        channelType != .direct
    }
    
    public func reloadMembers(_ members: [ChatChannelMember]) {
        var group = [UserId: ChatChannelMember]()
        for member in members {
            group[member.id] = member
        }
        if var newMembers = self.members {
            for (index, member) in newMembers.enumerated() {
                if let new = group[member.id] {
                    newMembers[index] = new
                }
            }
            self.members = newMembers
        }
        
    }
}

public extension ChatChannel {
    
    
    /*
     open lazy var messageObserver: LazyDatabaseObserver<MessageDTO, ChatMessage> = {
         return LazyDatabaseObserver<MessageDTO, ChatMessage>(
             context: Config.database.backgroundReadOnlyObservableContext,
             sortDescriptors: [.init(keyPath: \MessageDTO.createdAt, ascending: true),
                               .init(keyPath: \MessageDTO.id, ascending: true)],
             sectionNameKeyPath: #keyPath(MessageDTO.daySectionIdentifier),
             fetchPredicate: messageFetchPredicate,
             relationshipKeyPathsObserver: [
                 #keyPath(MessageDTO.attachments.status),
                 #keyPath(MessageDTO.attachments.filePath),
                 #keyPath(MessageDTO.user.avatarUrl),
                 #keyPath(MessageDTO.user.firstName),
                 #keyPath(MessageDTO.user.lastName),
                 #keyPath(MessageDTO.parent.state),
                 #keyPath(MessageDTO.bodyAttributes),
                 #keyPath(MessageDTO.linkMetadatas),
             ]
         ) { [weak self] in
             let message = $0.convert()
             self?.updateUnreadIndexIfNeeded(message: message)
             self?.createLayoutModel(for: message)
             return message
         }
         
     }()
     */
    
    public func createMembersObserver() {
        guard channelType == .direct,
              memberObserver == nil,
              let members,
              !members.isEmpty
        else { return }
        logger.debug("[ChatChannel] observer, start \(id), members: \(members.map { ($0.id, $0.blocked)})")
        let ids = members.map { $0.id }
        memberObserver = LazyDatabaseObserver<MemberDTO, ChatChannelMember>(
            context: Config.database.backgroundReadOnlyObservableContext,
            sortDescriptors: [.init(keyPath: \MemberDTO.channelId, ascending: true)],
            sectionNameKeyPath: nil,
            fetchPredicate: NSPredicate(format: "channelId == %lld AND user.id IN %@", id, ids),
            relationshipKeyPathsObserver: [
                #keyPath(MemberDTO.user.blocked),
                #keyPath(MemberDTO.user.state),
                #keyPath(MemberDTO.user.firstName),
                #keyPath(MemberDTO.user.lastName),
                #keyPath(MemberDTO.user.avatarUrl)
            ]
            
        ) { $0.convert() }
        
        memberObserver?.onDidChange = {[weak self] items, _ in
            guard let self
            else { return }
            Provider.database.read {
                MemberDTO.fetch(channelId: self.id, context: $0).map { $0.convert() }
            } completion: {[weak self] result in
                if let members = try? result.get() {
                    self?.members = members
                }
            }
        }
        try? memberObserver?.startObserver()
    }
}

extension ChatChannel: Hashable {
    
    public static func == (lhs: ChatChannel, rhs: ChatChannel) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

internal extension ChatChannel {
    
    var peer: ChatChannelMember? {
        let _peer = (channelType == .direct ? members?.first(where: {$0.id != me }) : nil)
        return _peer
    }
}
