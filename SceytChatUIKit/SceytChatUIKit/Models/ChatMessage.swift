//
//  ChatMessage.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat
import CoreData

public struct ChatMessage {
    
    public var id: MessageId
    public var tid: Int64
    public var channelId: ChannelId
    public var body: String
    public var type: String
    public var metadata: String?
    public var createdAt: Date
    public var updatedAt: Date?
    public var incoming: Bool
    public var transient: Bool
    public var silent: Bool
    public var state: State
    public var deliveryStatus: DeliveryStatus
    public var repliedInThread: Bool
    public var replyCount: Int
    public var displayCount: Int
    
    @CoreDataLazy public var attachments: [Attachment]?
    @CoreDataLazy public var selfReactions: [Reaction]?
    @CoreDataLazy public var reactionScores: [String: Int]?
    @CoreDataLazy public var mentionedUsers: [ChatUser]?
    @CoreDataLazy public var markerCount: [String: Int]?
    @CoreDataLazy public var selfMarkerNames: Set<String>?
    @CoreDataLazy public var linkMetadatas: [LinkMetadata]?
    @CoreDataLazy public var parent: ChatMessage?
    @CoreDataLazy public var user: ChatUser!
    @CoreDataLazy public var changedBy: ChatUser?
    
    public var forwardingDetails: ForwardingDetails?
    
    var hasDisplayedFromMe: Bool {
        selfMarkerNames?.contains(DeliveryStatus.displayed.rawValue) == true
    }
    
    init(id: MessageId,
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
         selfReactions: [ChatMessage.Reaction]? = nil,
         lastReactions: [ChatMessage.Reaction]? = nil,
         reactionScores: [String: Int]? = nil,
         mentionedUsers: [ChatUser]? = nil,
         markerCount: [String: Int]? = nil,
         selfMarkerNames: Set<String>? = nil,
         linkMetadatas: [ChatMessage.LinkMetadata]? = nil,
         user: ChatUser? = nil,
         changedBy: ChatUser? = nil,
         forwardingDetails: ForwardingDetails? = nil
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
        $attachments.0 = { attachments }
        $selfReactions.0 = { selfReactions }
        $reactionScores.0 = { reactionScores }
        $mentionedUsers.0 = { mentionedUsers }
        $markerCount.0 = { markerCount }
        $selfMarkerNames.0 = { selfMarkerNames }
        $linkMetadatas.0 = { linkMetadatas }
        $user.0 = { user }
        $changedBy.0 = { changedBy }
        self.forwardingDetails = forwardingDetails

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
        let context = dto.managedObjectContext
        $reactionScores = ( { dto.reactionScores }, context )
        $markerCount = ( { dto.markerCount }, context )
        if let user = dto.user {
            $user = ( { .init(dto: user) }, context )
        } else {
            $user.0 = { ChatUser(id: "") }
        }
        
        if let changedBy = dto.changedBy {
            $changedBy = ( {.init(dto: changedBy)}, context )
        }
        $selfReactions = ( { dto.selfReactions.map { $0.map {
            return .init(dto: $0)
        }}}, context)
        $attachments = ( { dto.attachments.map { $0.map {
            return .init(dto: $0)
        }}?.sorted(by: { item1, item2 in
            if let f1 = item1.filePath, let f2 = item2.filePath {
                return f1 < f2
            } else if let f1 = item1.url, let f2 = item2.url {
                return f1 < f2
            }
            return item1.type < item2.type
        })}, context)
        
        $mentionedUsers = ( { dto.mentionedUsers.map { $0.map {
            return .init(dto: $0)
        }}}, context)
        $selfMarkerNames = ( { dto.selfMarkerNames}, context)
        $linkMetadatas = ( { dto.linkMetadatas.map { $0.map {
            return .init(dto: $0)
        }}}, context )
        if let parentDto = dto.parent {
            $parent = ({ ChatMessage(dto: parentDto) }, context)
        }
        if dto.forwardMessageId > 0,
           dto.forwardChannelId > 0,
           let user = dto.forwardUser {
            forwardingDetails = ForwardingDetails(
                messageId: MessageId(dto.forwardMessageId),
                channelId: MessageId(dto.forwardChannelId),
                hops: dto.forwardHops,
                user: user)
        }
    }
    
    public init(message: Message, channelId: ChannelId) {
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
            selfReactions: message.selfReactions?.map { ChatMessage.Reaction(reaction: $0)},
            reactionScores: message.reactionScores.map { reactionScores in .init(uniqueKeysWithValues: reactionScores.map { ($0.key, Int($0.score))}) },
            mentionedUsers: message.mentionedUsers?.map { .init(user: $0) },
            markerCount: message.markerCount.map { markerCount in .init(uniqueKeysWithValues: markerCount.map { ($0.name, Int($0.count))}) },
            selfMarkerNames: message.selfMarkerNames.map { Set($0) },
            linkMetadatas: nil,
            user: .init(user: message.user),
            changedBy: nil,
            forwardingDetails: message.forwardingDetails.map {
                .init(
                    messageId: $0.messageId,
                    channelId: $0.channelId,
                    hops: Int64($0.hops),
                    user: .init(user: $0.user))
            }
        )
    }
}

extension ChatMessage {
    
    public enum State: String {
        case none
        case edited
        case deleted
        
        public init(rawValue: MessageState) {
            switch rawValue {
            case .none:
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
        
        var intValue: Int {
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
    
    public struct Attachment {
        public var id: AttachmentId
        public var messageId: MessageId
        public var userId: UserId
        public var localId: String
        public var url: String?
        public var filePath: String?
        public var type: String
        public var name: String?
        public var metadata: String?
        public var uploadedFileSize: UInt
        public var createdAt: Date
        public var status: TransferStatus
        public var transferProgress: Double
        
        public let imageDecodedMetadata: Metadata<String>?
        public let voiceDecodedMetadata: Metadata<[Int]>?
        
        @Lazy public var user: ChatUser?
        
        public var originUrl: URL {
            if let filePath {
                return URL(fileURLWithPath: filePath)
            }
            if let url, let _url = URL(string: url) {
                return _url
            }
            //should not be happen
            return URL(fileURLWithPath: "/")
        }
        
        init(
            id: AttachmentId,
            messageId: MessageId,
            userId: UserId,
            localId: String,
            url: String?,
            filePath: String?,
            type: String,
            name: String? = nil,
            metadata: String? = nil,
            uploadedFileSize: UInt,
            createdAt: Date,
            status: TransferStatus = .pending,
            transferProgress: Double = 0
        ) {
            self.id = id
            self.messageId = messageId
            self.userId = userId
            self.localId = localId
            self.url = url
            self.filePath = filePath
            self.type = type
            self.name = name
            self.metadata = metadata
            self.uploadedFileSize = uploadedFileSize
            self.createdAt = createdAt
            self.status = status
            self.transferProgress = transferProgress
            if let metadata {
                if type == "voice" {
                    voiceDecodedMetadata = try? Metadata<[Int]>.decode(metadata)
                    imageDecodedMetadata = nil
                } else {
                    imageDecodedMetadata = try? Metadata<String>.decode(metadata)
                    voiceDecodedMetadata = nil
                }
            } else {
                voiceDecodedMetadata = nil
                imageDecodedMetadata = nil
            }
            
            $user = {
                try? Provider.database.read {
                     UserDTO.fetch(id: userId, context: $0)?.convert()
                }.get()
            }
            
        }
        
        public init(dto: AttachmentDTO) {
            self.init(
                id: AttachmentId(dto.id),
                messageId: MessageId(dto.message?.id ?? 0),
                userId: dto.userId,
                localId: dto.localId,
                url: dto.url,
                filePath: dto.filePath,
                type: dto.type,
                name: dto.name,
                metadata: dto.metadata,
                uploadedFileSize: UInt(dto.uploadedFileSize),
                createdAt: dto.createdAt?.bridgeDate ?? .init(),
                status: TransferStatus(rawValue: dto.status) ?? .pending,
                transferProgress: dto.transferProgress
            )
        }
        
        public init(attachment: SceytChat.Attachment) {
            self.init(
                id: attachment.id,
                messageId: attachment.messageId,
                userId: attachment.userId,
                localId: "",
                url: attachment.url,
                filePath: attachment.filePath,
                type: attachment.type,
                name: attachment.name,
                metadata: attachment.metadata,
                uploadedFileSize: attachment.fileSize,
                createdAt: attachment.createdAt
            )
        }
        
        public enum TransferStatus: Int16 {
            case pending
            case uploading
            case downloading
            case pauseUploading
            case pauseDownloading
            case failedUploading
            case failedDownloading
            case done
        }
        
        public struct Metadata<T: Codable>: Codable {
            
            public var width: Int
            public var height: Int
            public var thumbnail: T
            public var duration: Int
            public var thumbnailData: Data?
            
            enum CodingKeys: String, CodingKey {
                case width = "szw"
                case height = "szh"
                case thumbnail = "tmb"
                case duration = "dur"
            }
            
            public init(
                width: Int = 0,
                height: Int = 0,
                thumbnail: T,
                duration: Int = 0
            ) {
                self.width = width
                self.height = height
                self.thumbnail = thumbnail
                self.duration = duration
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
                width = (try? container.decode(Int.self, forKey: CodingKeys.width)) ?? 0
                height = (try? container.decode(Int.self, forKey: CodingKeys.height)) ?? 0
                thumbnail = (try container.decode(T.self, forKey: CodingKeys.thumbnail))
                duration = (try? container.decode(Int.self, forKey: CodingKeys.duration)) ?? 0
                if let base64 = thumbnail as? String, !base64.isEmpty {
                    thumbnailData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
                }
            }
        }
    }
    
    public struct Reaction {
        
        public var key: String
        public var score: UInt
        public var reason: String?
        public var updatedAt: Date
        public var user: ChatUser!
        
        internal init(
            key: String,
            score: UInt,
            reason: String? = nil,
            updatedAt: Date = Date(),
            user: ChatUser? = nil
        ) {
            self.key = key
            self.score = score
            self.reason = reason
            self.updatedAt = updatedAt
            self.user = user
        }
        
        public init(dto: ReactionDTO) {
            key = dto.key
            score = UInt(dto.score)
            reason = dto.reason
            updatedAt = dto.updatedAt ?? Date()
            user = .init(dto: dto.user!)
        }
        
        public init(reaction: SceytChat.Reaction) {
            key = reaction.key
            score = UInt(reaction.score)
            reason = reaction.reason
            updatedAt = reaction.updatedAt
            user = .init(user: reaction.user)
        }
    }
    
    public struct ForwardingDetails {
        public var messageId: MessageId
        public var channelId: ChannelId
        public var hops: Int64
        @CoreDataLazy public var user: ChatUser?
        
        public init(
            messageId: MessageId,
            channelId: ChannelId,
            hops: Int64,
            user: ChatUser) {
                self.messageId = messageId
                self.channelId = channelId
                self.hops = hops
                $user.0 = { user }
            }
        
        public init(
            messageId: MessageId,
            channelId: ChannelId,
            hops: Int64,
            user: UserDTO) {
                self.messageId = messageId
                self.channelId = channelId
                self.hops = hops
                $user = ({ ChatUser(dto: user) }, user.managedObjectContext)
            }
    }
    
    public struct LinkMetadata {
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
    }
}

extension ChatMessage: Hashable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
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

extension ChatMessage.Attachment: Hashable {
    
    public static func == (lhs: ChatMessage.Attachment, rhs: ChatMessage.Attachment) -> Bool {
        if lhs.id != 0, rhs.id != 0 {
            return lhs.id == rhs.id
        }
        if !lhs.localId.isEmpty, !rhs.localId.isEmpty {
            return lhs.localId == rhs.localId
        }
        var isFile = true
        
        if lhs.url != nil, rhs.url != nil {
            isFile = lhs.url == rhs.url
        } else if lhs.filePath != nil, rhs.filePath != nil {
            isFile = lhs.filePath == rhs.filePath
        }
        
        return isFile && lhs.type == rhs.type && lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(localId)
        hasher.combine(filePath)
        hasher.combine(type)
    }
}

extension ChatMessage.Reaction: Hashable {
    
    public static func == (lhs: ChatMessage.Reaction, rhs: ChatMessage.Reaction) -> Bool {
        lhs.key == rhs.key && lhs.user.id == rhs.user.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(user.id)
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
        return b
    }
}

public extension ChatMessage.Attachment {
    
    var builder: Attachment.Builder {
        let b = url != nil ? Attachment.Builder(url: url!, type: type) :
        Attachment.Builder(filePath: filePath ?? "", type: type)
        if let name {
            b.name(name)
        }
        if let metadata {
            b.metadata(metadata)
        }
        if uploadedFileSize > 0 {
            b.fileSize(uploadedFileSize)
        }
        return b
    }
}
