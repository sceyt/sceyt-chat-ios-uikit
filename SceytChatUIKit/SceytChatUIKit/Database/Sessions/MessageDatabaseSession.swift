//
//  MessageDatabaseSession.swift
//  SceytChatUIKit
//

import Foundation
import CoreData
import SceytChat

public protocol MessageDatabaseSession {

    @discardableResult
    func createOrUpdate(message: Message, channelId: ChannelId, changedBy: User?) -> MessageDTO
    
    @discardableResult
    func update(chatMessage: ChatMessage, attachments: [ChatMessage.Attachment]?) -> MessageDTO?
    
    @discardableResult
    func createOrUpdate(messages: [Message], channelId: ChannelId) -> [MessageDTO]

    @discardableResult
    func createOrUpdate(attachments: [Attachment], dto: MessageDTO) -> MessageDTO

    @discardableResult
    func createOrUpdate(selfReactions: [Reaction], dto: MessageDTO) -> MessageDTO

    @discardableResult
    func createOrUpdate(requestedMentionUserIds: [UserId], dto: MessageDTO) -> MessageDTO
    
    @discardableResult
    func createOrUpdate(mentionedUsers: [User], dto: MessageDTO) -> MessageDTO

    @discardableResult
    func createOrUpdate(reactionScores: [ReactionScore], dto: MessageDTO) -> MessageDTO

    @discardableResult
    func createOrUpdate(selfMarkerNames: [String], dto: MessageDTO) -> MessageDTO
    
    @discardableResult
    func createOrUpdate(forwardDetail: ForwardingDetails?, dto: MessageDTO) -> MessageDTO

    @discardableResult
    func add(linkMetadatas: [LinkMetadata], toMessage id: MessageId) -> MessageDTO

    @discardableResult
    func update(messageMarkers: MessageListMarker) -> [MessageDTO]
    
    @discardableResult
    func update(messageSelfMarkers: MessageListMarker) -> [MessageDTO]
  
    func deleteMessage(id: MessageId)
    func deleteMessage(tid: Int64)
    
    func set(newFilePath: String, chatMessage: ChatMessage, attachment: ChatMessage.Attachment)
}

public extension MessageDatabaseSession {

    @discardableResult
    func createOrUpdate(message: Message, channelId: ChannelId) -> MessageDTO {
        createOrUpdate(message: message, channelId: channelId, changedBy: nil)
    }
}

extension NSManagedObjectContext: MessageDatabaseSession {
    
    @discardableResult
    public func createOrUpdate(message: Message, channelId: ChannelId, changedBy: User?) -> MessageDTO {
        let dto = MessageDTO.fetchOrCreate(id: message.id, tid: Int64(message.tid), context: self).map(message)
        dto.channelId = Int64(channelId)
        if dto.ownerChannel?.id != Int64(channelId) {
            dto.ownerChannel = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        }
        dto.user = createOrUpdate(user: message.user)
        if let changedBy = changedBy {
            dto.changedBy = createOrUpdate(user: changedBy)
        }
        
        if let mentionedUsers = message.mentionedUsers, !mentionedUsers.isEmpty {
            createOrUpdate(mentionedUsers: mentionedUsers, dto: dto)
        } else if let requestedMentionUserIds = message.requestedMentionUserIds, !requestedMentionUserIds.isEmpty {
            createOrUpdate(requestedMentionUserIds: requestedMentionUserIds, dto: dto)
        }
        createOrUpdate(attachments: message.attachments ?? [], dto: dto)
        createOrUpdate(selfReactions: message.selfReactions ?? [], dto: dto)
        createOrUpdate(reactionScores: message.reactionScores ?? [], dto: dto)
        createOrUpdate(selfMarkerNames: message.selfMarkerNames ?? [], dto: dto)
        createOrUpdate(forwardDetail: message.forwardingDetails, dto: dto)
        
        if dto.markerCount == nil {
            dto.markerCount = .init()
        }
        for marker in message.markerCount ?? [] {
            dto.markerCount![marker.name] = Int(marker.count)
        }
        
        if let channel = dto.ownerChannel {
            if let lastMessage = channel.lastMessage {
                if (lastMessage.id != 0 && dto.id != 0) {
                    if lastMessage.id <= dto.id {
                        channel.lastMessage = dto
                    }
                } else if lastMessage.createdAt.bridgeDate < dto.createdAt.bridgeDate {
                    channel.lastMessage = dto
                }
            } else {
                channel.lastMessage = dto
            }
        }
        
        if let parent = message.parent {
            if message.id > 0 {
                dto.parent = createOrUpdate(message: parent, channelId: channelId)
            } else {
                dto.parent = MessageDTO.fetch(id: parent.id, context: self)
            }
        } else if message.state == .deleted {
            dto.parent = nil
        }
        return dto
    }

    @discardableResult
    public func createOrUpdate(messages: [Message], channelId: ChannelId) -> [MessageDTO] {
        messages.map { createOrUpdate(message: $0, channelId: channelId) }
    }
    
    @discardableResult
    public func update(chatMessage: ChatMessage, attachments: [ChatMessage.Attachment]?) -> MessageDTO? {
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        var predicates = [NSPredicate]()
        if chatMessage.id != 0 {
            predicates.append(.init(format: "id == %lld", chatMessage.id))
        }
        if chatMessage.tid != 0 {
            predicates.append(.init(format: "tid == %lld", chatMessage.tid))
        }
        guard !predicates.isEmpty
        else { return nil }
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        guard let dto = MessageDTO.fetch(request: request, context: self).first
        else { return nil }
        
        //Attachment
        attachments?.forEach({
            var attachmentDTO: AttachmentDTO?
            if !$0.localId.isEmpty {
                attachmentDTO = AttachmentDTO.fetch(localId: $0.localId, context: self)
            } else if let filePath = $0.filePath {
                attachmentDTO = AttachmentDTO.fetchOrCreate(filePath: filePath, message: dto, context: self)
            } else if let url = $0.url {
                attachmentDTO = AttachmentDTO.fetchOrCreate(url: url, message: dto, context: self)
            }
            guard let attachmentDTO else { return }
            if let url = $0.url {
                attachmentDTO.url = url
            }
            if let filePath = $0.filePath {
                attachmentDTO.filePath = filePath
            }
            attachmentDTO.transferProgress = $0.transferProgress
            attachmentDTO.status = $0.status.rawValue
            attachmentDTO.name = $0.name
        })
        return dto
    }
    

    @discardableResult
    public func createOrUpdate(attachments: [Attachment], dto: MessageDTO) -> MessageDTO {
        dto.attachments = .init(
            attachments.compactMap {
                var attachmentDTO: AttachmentDTO?
                if let filePath = $0.filePath {
                    attachmentDTO = AttachmentDTO.fetchOrCreate(filePath: filePath, message: dto, context: self).map($0)
                } else if let url = $0.url {
                    attachmentDTO = AttachmentDTO.fetchOrCreate(url: url, message: dto, context: self).map($0)
                }
                return attachmentDTO
            })
        return dto
    }

    @discardableResult
    public func createOrUpdate(selfReactions: [Reaction], dto: MessageDTO) -> MessageDTO {
        dto.selfReactions = .init(
            selfReactions.map {
                let dto = ReactionDTO.create(context: self)
                    .map($0)
                dto.user = createOrUpdate(user: $0.user)
                return dto
            })
        return dto
    }

    @discardableResult
    public func createOrUpdate(requestedMentionUserIds: [UserId], dto: MessageDTO) -> MessageDTO {
        dto.mentionedUsers = .init(
            requestedMentionUserIds.compactMap {
                UserDTO.fetch(id: $0, context: self)
            })
        return dto
    }

    @discardableResult
    public func createOrUpdate(mentionedUsers: [User], dto: MessageDTO) -> MessageDTO {
        dto.mentionedUsers = .init(
            mentionedUsers.map {
                createOrUpdate(user: $0)
            })
        return dto
    }

    @discardableResult
    public func createOrUpdate(reactionScores: [ReactionScore], dto: MessageDTO) -> MessageDTO {
        dto.reactionScores = .init(uniqueKeysWithValues: reactionScores.map { ($0.key, Int($0.score))})
        return dto
    }

    @discardableResult
    public func createOrUpdate(selfMarkerNames: [String], dto: MessageDTO) -> MessageDTO {
        guard !selfMarkerNames.isEmpty else { return dto }
        let union = Set(selfMarkerNames)
        
        if dto.selfMarkerNames == nil {
            dto.selfMarkerNames = .init()
        }
        if dto.selfMarkerNames != union {
            dto.selfMarkerNames!.formUnion(union)
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(forwardDetail: ForwardingDetails?, dto: MessageDTO) -> MessageDTO {
        if let forwardDetail {
            dto.forwardMessageId = Int64(forwardDetail.messageId)
            if dto.deliveryStatus == ChatMessage.DeliveryStatus.pending.intValue {
                if let message = MessageDTO.fetch(id: forwardDetail.messageId, context: self) {
                    dto.forwardChannelId = message.channelId
                    dto.forwardHops = 0
                    dto.forwardUser = message.user
                }
            } else {
                dto.forwardChannelId = Int64(forwardDetail.channelId)
                dto.forwardHops = Int64(forwardDetail.hops)
                dto.forwardUser = createOrUpdate(user: forwardDetail.user)
            }
            
        } else {
            dto.forwardMessageId = 0
            dto.forwardChannelId = 0
            dto.forwardHops = 0
            dto.forwardUser = nil
        }
        return dto
    }

    @discardableResult
    public func add(linkMetadatas: [LinkMetadata], toMessage id: MessageId) -> MessageDTO {
        let dto = MessageDTO.fetchOrCreate(id: id, context: self)
        let links: Set<LinkMetadataDTO> = .init(
            linkMetadatas.map {
                LinkMetadataDTO.fetchOrCreate(
                    url: $0.url,
                    context: self
                ).map($0)
            })
        if dto.linkMetadatas == nil {
            dto.linkMetadatas = links
        } else {
            dto.linkMetadatas?.formUnion(links)
        }
        return dto
    }

    @discardableResult
    public func update(messageMarkers: MessageListMarker) -> [MessageDTO] {
        guard let status = ChatMessage.DeliveryStatus(rawValue: messageMarkers.name),
              !messageMarkers.messageIds.isEmpty
        else { return [] }
        let maxId = messageMarkers.messageIds.max(by: { $0.int64Value < $1.int64Value}) ?? messageMarkers.messageIds.last!
        guard let channelId = MessageDTO.fetch(id: MessageId(maxId.int64Value), context: self)?.channelId
        else { return [] }
        let predicate = NSPredicate(
            format: "channelId == %lld AND id <= %@ AND deliveryStatus != %d AND deliveryStatus != %d AND deliveryStatus < %d AND incoming == false",
            channelId,
            maxId,
            ChatMessage.DeliveryStatus.pending.intValue,
            ChatMessage.DeliveryStatus.failed.intValue,
            status.intValue)
        
        let messages = MessageDTO.fetch(
            predicate: predicate,
            context: self
        )

        messages.forEach {
            $0.deliveryStatus = Int16(status.preferredStatus(for: Int($0.deliveryStatus)).intValue)
        }
        if messageMarkers.user.id == me {
            update(messageSelfMarkers: messageMarkers)
        }
        return messages
    }
    
    @discardableResult
    public func update(messageSelfMarkers: MessageListMarker) -> [MessageDTO] {
        let predicate = NSPredicate(format: "id IN %@",
                                    messageSelfMarkers.messageIds.map { MessageId($0.uint64Value)})
        let messages = MessageDTO.fetch(
            predicate: predicate,
            context: self
        )
        
        messages.forEach {
            if $0.selfMarkerNames == nil {
                $0.selfMarkerNames = .init(arrayLiteral: messageSelfMarkers.name)
            } else {
                $0.selfMarkerNames!.insert(messageSelfMarkers.name)
            }
            if $0.markerCount?[messageSelfMarkers.name] == nil {
                if $0.markerCount == nil {
                    $0.markerCount = .init()
                }
                $0.markerCount![messageSelfMarkers.name] = 1
            }
           
            $0.pendingMarkerNames?.remove(messageSelfMarkers.name)
            if $0.pendingMarkerNames != nil, $0.pendingMarkerNames!.isEmpty {
                $0.pendingMarkerNames = nil
            }
        }
        return messages
    }
    
    
    @discardableResult
    public func update(messagePendingMarkers messageIds: [MessageId], markerName: String) -> [MessageDTO] {
        let predicate = NSPredicate(format: "id IN %@", messageIds)
        let messages = MessageDTO.fetch(
            predicate: predicate,
            context: self
        )
        
        messages.forEach {
            if $0.pendingMarkerNames == nil {
                $0.pendingMarkerNames = .init(arrayLiteral: markerName)
            } else {
                $0.pendingMarkerNames!.insert(markerName)
            }
        }
        return messages
    }

    public func deleteMessage(id: MessageId) {
        if let dto = MessageDTO.fetch(id: id, context: self) {
            delete(dto)
        }
    }

    public func deleteMessage(tid: Int64) {
        if let dto = MessageDTO.fetch(tid: tid, context: self) {
            delete(dto)
        }
    }
    
    public func set(newFilePath: String, chatMessage: ChatMessage, attachment: ChatMessage.Attachment) {
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        var predicates = [NSPredicate]()
        if chatMessage.id != 0 {
            predicates.append(.init(format: "id == %lld", chatMessage.id))
        }
        if chatMessage.tid != 0 {
            predicates.append(.init(format: "tid == %lld", chatMessage.tid))
        }
        guard !predicates.isEmpty
        else { return}
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        guard let dto = MessageDTO.fetch(request: request, context: self).first
        else { return }
        var attachmentDTO: AttachmentDTO?
        if !attachment.localId.isEmpty {
            attachmentDTO = AttachmentDTO.fetch(localId: attachment.localId, context: self)
        } else if let filePath = attachment.filePath {
            attachmentDTO = AttachmentDTO.fetchOrCreate(filePath: filePath, message: dto, context: self)
        } else if let url = attachment.url {
            attachmentDTO = AttachmentDTO.fetchOrCreate(url: url, message: dto, context: self)
        }
        attachmentDTO?.filePath = newFilePath
    }

    public func deleteAllMessages(
        channelId: ChannelId,
        messagesDeletionDate: Date? = nil
    ) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: MessageDTO.entityName)
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        var predicate = NSPredicate(format: "ownerChannel.id == %lld", channelId)
        if let messagesDeletionDate {
            predicate = NSCompoundPredicate(type: .and, subpredicates: [
                predicate,
                NSPredicate(format: "createdAt <= %@", messagesDeletionDate as NSDate)
            ])
        }
        request.predicate = predicate
        try batchDelete(fetchRequest: request)
        if let messagesDeletionDate,
           let channel = ChannelDTO.fetch(id: channelId, context: self) {
            if let lastMessage = channel.lastMessage {
                if messagesDeletionDate >= lastMessage.createdAt.bridgeDate {
                    channel.lastMessage = nil
                    channel.messages = nil
                    channel.lastReceivedMessageId = 0
                    channel.lastDisplayedMessageId = 0
                }
            } else {
                channel.lastReceivedMessageId = 0
                channel.lastDisplayedMessageId = 0
            }
        }
    }
}
