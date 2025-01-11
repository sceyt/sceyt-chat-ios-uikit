//
//  ChatMessage.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import CoreData

public class ChatMessage {
    
    public let id: MessageId
    public let tid: Int64
    public let channelId: ChannelId
    public let body: String
    public let type: String
    public let metadata: String?
    public let createdAt: Date
    public let updatedAt: Date?
    public let incoming: Bool
    public let transient: Bool
    public let silent: Bool
    public let state: State
    public let deliveryStatus: DeliveryStatus
    public let repliedInThread: Bool
    public let replyCount: Int
    public let displayCount: Int
    
    public let attachments: [Attachment]?
    public let userReactions: [Reaction]?
    public let userPendingReactions: [Reaction]?
    public let reactionTotal: [ReactionTotal]?
    public let reactionScores: [String: Int64]?
    public let mentionedUsers: [ChatUser]?
    public let markerCount: [String: Int]?
    public let userMarkers: [Marker]?
    public let linkMetadatas: [LinkMetadata]?
    public let parent: ChatMessage?
    public let user: ChatUser!
    public let changedBy: ChatUser?
    public let reactions: [Reaction]?
    public let forwardingDetails: ForwardingDetails?
    public let bodyAttributes: [BodyAttribute]?

    var hasDisplayedFromMe: Bool {
        userMarkers?.contains(where: { $0.user?.id == SceytChatUIKit.shared.currentUserId && $0.name == DeliveryStatus.displayed.rawValue} ) == true
    }
    
    public init(id: MessageId,
                tid: Int64 = 0,
                channelId: ChannelId,
                body: String = "",
                type: String = "txt",
                metadata: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date? = nil,
                incoming: Bool = false,
                transient: Bool = false,
                silent: Bool = false,
                state: ChatMessage.State = .none,
                deliveryStatus: ChatMessage.DeliveryStatus = .pending,
                repliedInThread: Bool = false,
                replyCount: Int = 0,
                displayCount: Int = 0,
                attachments: [ChatMessage.Attachment]? = nil,
                userReactions: [ChatMessage.Reaction]? = nil,
                userPendingReactions: [ChatMessage.Reaction]? = nil,
                reactionTotals: [ChatMessage.ReactionTotal]? = nil,
                mentionedUsers: [ChatUser]? = nil,
                markerCount: [String: Int]? = nil,
                userMarkers: [Marker]? = nil,
                linkMetadatas: [ChatMessage.LinkMetadata]? = nil,
                user: ChatUser? = nil,
                changedBy: ChatUser? = nil,
                forwardingDetails: ForwardingDetails? = nil,
                bodyAttributes: [BodyAttribute]? = nil
    ) {
        self.id = id
        self.tid = tid
        self.channelId = channelId
        self.body = body
        self.type = type
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.incoming = incoming
        self.transient = transient
        self.silent = silent
        self.state = state
        self.deliveryStatus = deliveryStatus
        self.repliedInThread = repliedInThread
        self.replyCount = replyCount
        self.displayCount = displayCount
        self.attachments = attachments
        self.userReactions = userReactions
        self.userPendingReactions = userPendingReactions
        self.reactionTotal = reactionTotals
        self.mentionedUsers = mentionedUsers
        self.markerCount = markerCount
        self.userMarkers = userMarkers
        self.linkMetadatas = linkMetadatas
        self.user = user
        self.changedBy = changedBy
        self.forwardingDetails = forwardingDetails
        reactions = nil
        parent = nil
        var reactionScores = [String: Int64]()
        if let reactionTotal = reactionTotal {
            for total in reactionTotal {
                reactionScores[total.key] = Int64(total.score)
            }
        }
        self.reactionScores = reactionScores
        self.bodyAttributes = bodyAttributes
    }
    
    public init(dto: MessageDTO) {
        id = MessageId(dto.id)
        tid = dto.tid
        channelId = ChannelId(dto.channelId)
        body = dto.body
        type = dto.type
        metadata = dto.metadata
        createdAt = dto.createdAt.bridgeDate
        updatedAt = dto.updatedAt?.bridgeDate
        incoming = dto.incoming
        transient = dto.transient
        silent = dto.silent
        state = State(rawValue: Int(dto.state)) ?? .none
        deliveryStatus = DeliveryStatus(rawValue: Int(dto.deliveryStatus)) ?? .pending
        repliedInThread = dto.repliedInThread
        replyCount = Int(dto.replyCount)
        displayCount = Int(dto.displayCount)
        markerCount = dto.markerTotal
        if let user = dto.user {
            self.user = user.convert()
        } else {
            logger.verbose("Could not get user from db for message id: \(dto.id)")
            user = ChatUser(id: "")
        }
        if let changedBy = dto.changedBy {
            self.changedBy = .init(dto: changedBy)
        } else {
            changedBy = nil
        }
        
        attachments = dto.attachments?.map {
            $0.convert()
        }.sorted(by: { item1, item2 in
            if let f1 = item1.filePath, let f2 = item2.filePath {
                return f1 < f2
            } else if let f1 = item1.url, let f2 = item2.url {
                return f1 < f2
            }
            return item1.type < item2.type
        })
        
        mentionedUsers = {
            var map = [UserId: ChatUser]()
            for dto in dto.mentionedUsers ?? [] {
                map[dto.id] = dto.convert()
            }
            var users = [ChatUser]()
            for id in dto.orderedMentionedUserIds ?? [] {
                if let user = map[id] {
                    users.append(user)
                }
            }
            return users
        }()
        
        if let markers = dto.userMarkers?.map({ $0.convert() }) {
            userMarkers = .init(markers)
        } else {
            userMarkers = nil
        }
        
        linkMetadatas = dto.linkMetadatas?.map {
            return .init(dto: $0)
        }
        if let parentDto = dto.parent {
            parent = ChatMessage(dto: parentDto)
        } else {
            parent = nil
        }
        if dto.forwardMessageId > 0,
           dto.forwardChannelId > 0,
           let user = dto.forwardUser {
            forwardingDetails = ForwardingDetails(
                messageId: MessageId(dto.forwardMessageId),
                channelId: MessageId(dto.forwardChannelId),
                hops: dto.forwardHops,
                user: user)
        } else {
            forwardingDetails = nil
        }
        
        userReactions = dto.userReactions?.map {
            $0.convert()
        }.sorted(by: { $0.createdAt < $1.createdAt })
        
        userPendingReactions = dto.pendingReactions?.map {
            $0.convert()
        }.sorted(by: { $0.createdAt < $1.createdAt })
        
        reactions = dto.reactions?.map {
            $0.convert()
        }

        bodyAttributes = dto.bodyAttributes?.map { $0.convert() }

        var reactionScores = [String: Int64]()
        var rt = [ReactionTotal]()
        if let reactionTotal = dto.reactionTotal {
            for total in reactionTotal where total.score > 0 {
                reactionScores[total.key] = total.score
                rt.append(total.convert())
            }
        }
        
        if let pendingReactions = dto.pendingReactions {
            for pendingReaction in pendingReactions where pendingReaction.score > 0 {
                if reactionScores[pendingReaction.key] != nil {
                    reactionScores[pendingReaction.key]! += Int64(pendingReaction.score)
                } else {
                    reactionScores[pendingReaction.key] = Int64(pendingReaction.score)
                }
            }
        }
        self.reactionScores = reactionScores
        self.reactionTotal = rt
        userReactions?.forEach( { $0.message = self })
        userPendingReactions?.forEach({ $0.message = self})
        reactions?.forEach( { $0.message = self })
        
    }
    
    public convenience init(message: Message, channelId: ChannelId) {
        //MARK: db RENAME
        self.init(
            id: message.id,
            tid: Int64(message.tid),
            channelId: channelId,
            body: message.body,
            type: message.type,
            metadata: message.metadata,
            createdAt: message.createdAt,
            updatedAt: message.updatedAt,
            incoming: message.incoming,
            transient: message.transient,
            silent: message.silent,
            state: .init(rawValue: message.state),
            deliveryStatus: .init(rawValue: message.deliveryStatus),
            repliedInThread: message.repliedInThread,
            replyCount: message.replyCount,
            displayCount: message.displayCount,
            attachments: message.attachments?.map { ChatMessage.Attachment(attachment: $0)},
            userReactions: message.userReactions?.map { ChatMessage.Reaction(reaction: $0)},
            reactionTotals: message.reactionTotals?.map { .init(reaction: $0)},
            mentionedUsers: message.mentionedUsers?.map { .init(user: $0) },
            markerCount: nil,//,message.markerTotals?.map { markerCount in .init(uniqueKeysWithValues: markerCount.map { ($0.name, Int($0.count))}) },
            userMarkers: message.userMarkers?.map({ .init(marker: $0)}),
            linkMetadatas: nil,
            user: .init(user: message.user),
            changedBy: nil,
            forwardingDetails: message.forwardingDetails.map {
                .init(
                    messageId: $0.messageId,
                    channelId: $0.channelId,
                    hops: Int64($0.hops),
                    user: .init(user: $0.user))
            },
            bodyAttributes: message.bodyAttributes?.map {
                .init(offset: $0.offset, length: $0.length, type: .init(rawValue: $0.type) ?? .none, metadata: $0.metadata)
            }
        )
    }
}

extension ChatMessage {
    
    public enum State: String {
        case none
        case edited
        case deleted
        //MARK: db RENAME
        public init(rawValue: MessageState) {
            switch rawValue {
            case .unmodified:
                self = .none
            case .edited:
                self = .edited
            case .deleted:
                self = .deleted
            @unknown default:
                self = .none
            }
        }
        
        public init?(rawValue: Int) {
            switch rawValue {
            case 0:
                self = .none
            case 1:
                self = .edited
            case 2:
                self = .deleted
            default:
                return nil
            }
        }
        
        var intValue: Int {
            switch self {
            case .none:
                return MessageState.unmodified.rawValue
            case .edited:
                return MessageState.edited.rawValue
            case .deleted:
                return MessageState.deleted.rawValue
            }
        }
    }
    
    public enum DeliveryStatus: String {
        case pending
        case sent
        case received
        case displayed
        case failed
        
        public init(rawValue: MessageDeliveryStatus) {
            switch rawValue {
            case .pending:
                self = .pending
            case .sent:
                self = .sent
            case .received:
                self = .received
            case .displayed:
                self = .displayed
            case .failed:
                self = .failed
            @unknown default:
                self = .sent
            }
        }
        
        public init?(rawValue: Int) {
            switch rawValue {
            case 0:
                self = .pending
            case 1:
                self = .sent
            case 2:
                self = .received
            case 3:
                self = .displayed
            case 4:
                self = .failed
            default:
                return nil
            }
        }
        
        public var intValue: Int {
            switch self {
            case .pending:
                return 0
            case .sent:
                return 1
            case .received:
                return 2
            case .displayed:
                return 3
            case .failed:
                return 4
            }
        }
        
        func preferredStatus(for rawValue: Int) -> DeliveryStatus {
            switch self {
            case .pending, .failed:
                return .init(rawValue: rawValue) ?? .failed
            default:
                return .init(
                    rawValue: max(self.intValue,
                                  min(rawValue, DeliveryStatus.failed.intValue)))
                ?? DeliveryStatus.failed
            }
        }
    }
}

extension ChatMessage {
    
    public struct ForwardingDetails {
        public var messageId: MessageId
        public var channelId: ChannelId
        public var hops: Int64
        public var user: ChatUser?
        
        public init(
            messageId: MessageId,
            channelId: ChannelId,
            hops: Int64,
            user: ChatUser) {
                self.messageId = messageId
                self.channelId = channelId
                self.hops = hops
                self.user = user
            }
        
        public init(
            messageId: MessageId,
            channelId: ChannelId,
            hops: Int64,
            user: UserDTO) {
                self.messageId = messageId
                self.channelId = channelId
                self.hops = hops
                self.user = ChatUser(dto: user)
            }
    }
    
    public struct LinkMetadata: Equatable {
        public var url: URL
        public var title: String?
        public var summary: String?
        public var creator: String?
        public var iconUrl: URL?
        public var imageUrl: URL?
                
        public init(
            url: URL,
            title: String? = nil,
            summary: String? = nil,
            creator: String? = nil,
            iconUrl: URL? = nil,
            imageUrl: URL? = nil
        ) {
            self.url = url
            self.title = title
            self.summary = summary
            self.creator = creator
            self.iconUrl = iconUrl
            self.imageUrl = imageUrl
        }
        
        public init(dto: LinkMetadataDTO) {
            url = dto.url
            title = dto.title
            summary = dto.summary
            creator = dto.creator
            iconUrl = dto.iconUrl
            imageUrl = dto.imageUrl
        }
        
        public static func == (lhs: LinkMetadata, rhs: LinkMetadata) -> Bool {
            lhs.url == rhs.url
        }
    }
}

extension ChatMessage: Hashable {
    
    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        if lhs.tid != 0, rhs.tid != 0 {
            return lhs.tid == rhs.tid
        }
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        if tid != 0 {
            hasher.combine(tid)
        } else if id > 0 {
            hasher.combine(id)
        }
    }
}

extension ChatMessage: Comparable {
    
    public static func < (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        //MARK: first compare by createdAt then by id
        if lhs.createdAt == rhs.createdAt {
            return lhs.id < rhs.id
        }
        return lhs.createdAt < rhs.createdAt
    }
}

public extension ChatMessage {
    
    var builder: Message.Builder {
        let b = Message.Builder()
            .id(id)
            .tid(Int(tid))
            .body(body)
            .type(type)
            .replyInThread(repliedInThread)
            .transient(transient)
            .displayCount(displayCount)
            .silent(silent)
        if let metadata {
            b.metadata(metadata)
        }
        if let mentionedUsers {
            b.mentionUserIds(mentionedUsers.map { $0.id })
        }
        if let parent {
            b.parentMessageId(parent.id)
        }
        if let attachments {
            b.attachments(attachments.map { $0.builder.build() })
        }
        if let fwId = forwardingDetails?.messageId {
            b.forwardingMessageId(fwId)
        }
        if let bodyAttributes {
            b.bodyAttributes(bodyAttributes.map { .init(offset: $0.offset, length: $0.length, type: $0.type.rawValue, metadata: $0.metadata) })
        }
        return b
    }
}


