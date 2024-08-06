//
//  MessageDatabaseSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

public protocol MessageDatabaseSession {
    @discardableResult
    func createOrUpdate(message: Message, channelId: ChannelId, changedBy: User?) -> MessageDTO
    
    @discardableResult
    func update(message: Message, channelId: ChannelId) -> MessageDTO?
    
    @discardableResult
    func update(chatMessage: ChatMessage, attachments: [ChatMessage.Attachment]?) -> MessageDTO?
    
    @discardableResult
    func createOrUpdate(messages: [Message], channelId: ChannelId) -> [MessageDTO]

    @discardableResult
    func createOrUpdate(attachments: [Attachment], dto: MessageDTO) -> MessageDTO
    
    @discardableResult
    func createOrUpdate(attachment: Attachment, channelId: ChannelId) -> AttachmentDTO
    
    @discardableResult
    func createOrUpdate(attachments: [Attachment], channelId: ChannelId) -> [AttachmentDTO]

    @discardableResult
    func createOrUpdate(userReactions: [Reaction], dto: MessageDTO) -> MessageDTO
    
    @discardableResult
    func createOrUpdate(reactions: [Reaction]) -> [ReactionDTO]
    
    @discardableResult
    func add(reaction: Reaction) -> ReactionDTO?
    
    @discardableResult
    func delete(reaction: Reaction) -> ReactionDTO?

    @discardableResult
    func createOrUpdate(requestedMentionUserIds: [UserId], dto: MessageDTO) -> MessageDTO
    
    @discardableResult
    func createOrUpdate(mentionedUsers: [User], dto: MessageDTO) -> MessageDTO

    @discardableResult
    func createOrUpdate(reactionTotal: [ReactionTotal], dto: MessageDTO, deleteNotExistReactions: Bool) -> MessageDTO

    @discardableResult
    func createOrUpdate(userMarkers: [Marker], dto: MessageDTO) -> MessageDTO
    
    @discardableResult
    func createOrUpdate(forwardDetail: ForwardingDetails?, dto: MessageDTO) -> MessageDTO

    @discardableResult
    func add(linkMetadatas: [LinkMetadata], messageId: MessageId) -> MessageDTO?
    
    @discardableResult
    func add(linkMetadatas: [LinkMetadata], messageTid: Int64) -> MessageDTO?
    
    func add(linkMetadatas: [LinkMetadata], dto: MessageDTO)

    @discardableResult
    func update(messageMarkers: MessageListMarker) -> [MessageDTO]
    
    @discardableResult
    func update(messageSelfMarkers: MessageListMarker) -> [MessageDTO]
    
    @discardableResult
    func createOrUpdate(marker: Marker, messageId: MessageId) -> MarkerDTO
    
    @discardableResult
    func createOrUpdate(markers: [Marker], messageId: MessageId) -> [MarkerDTO]
    
    @discardableResult
    func addPendingReaction(messageId: MessageId, key: String, score: UInt16, reason: String?, enforceUnique: Bool) -> (MessageDTO, ReactionDTO)?
    
    @discardableResult
    func removePendingReaction(messageId: MessageId, key: String) -> MessageDTO?
  
    func deleteMessage(id: MessageId)
    func deleteMessage(tid: Int64)
    func deleteReaction(id: ReactionId)
    func deleteNotExistReactions(_ reactions: [Reaction])
    func deleteAttachmentsFor(messageId: MessageId)
    func deleteAttachmentsFor(messageTid: Int64)
    func deleteAttachmentsFor(message: Message)
    func deleteAttachment(id: AttachmentId)
    
    func updateAttachment(with filePath: String, chatMessage: ChatMessage, attachment: ChatMessage.Attachment)
    
    @discardableResult
    func createOrUpdate(notificationContent userInfo: [AnyHashable: Any]) throws -> MessageDTO?
    
    @discardableResult
    func createOrUpdate(checksum: ChatMessage.Attachment.Checksum) -> ChecksumDTO
    
    @discardableResult
    func updateChecksum(data: String, messageTid: Int64, attachmentTid: Int64) -> ChecksumDTO?
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
        let dto = MessageDTO.fetchOrCreate(id: message.id, tid: message.incoming ? 0 : Int64(message.tid), context: self).map(message)
        dto.channelId = Int64(channelId)
        let ownerChannel = ChannelDTO.fetch(id: channelId, context: self)
        dto.user = createOrUpdate(user: message.user)
        if let changedBy = changedBy {
            dto.changedBy = createOrUpdate(user: changedBy)
        }
        
        if let mentionedUsers = message.mentionedUsers, !mentionedUsers.isEmpty {
            createOrUpdate(mentionedUsers: mentionedUsers, dto: dto)
        } else if let requestedMentionUserIds = message.requestedMentionUserIds, !requestedMentionUserIds.isEmpty {
            createOrUpdate(requestedMentionUserIds: requestedMentionUserIds, dto: dto)
        }
        if message.state == .deleted {
            deleteAttachmentsFor(message: message)
        } else {
            createOrUpdate(attachments: message.attachments ?? [], dto: dto)
        }
        
        createOrUpdate(userReactions: message.userReactions ?? [], dto: dto)
        createOrUpdate(reactionTotal: message.reactionTotals ?? [], dto: dto, deleteNotExistReactions: true)
        createOrUpdate(userMarkers: message.userMarkers ?? [], dto: dto)
        createOrUpdate(forwardDetail: message.forwardingDetails, dto: dto)
        createOrUpdate(bodyAttributes: message.bodyAttributes, dto: dto)
        
        if dto.markerTotal == nil {
            dto.markerTotal = .init()
        }
        for marker in message.markerTotals ?? [] {
            dto.markerTotal![marker.name] = Int(marker.count)
        }
        
        if let channel = ownerChannel {
            if let lastMessage = channel.lastMessage {
                if lastMessage.id != 0 && dto.id != 0 {
                    if lastMessage.id <= dto.id {
                        channel.lastMessage = dto
                    }
                } else if lastMessage.createdAt.bridgeDate < dto.createdAt.bridgeDate {
                    channel.lastMessage = dto
                }
            } else {
                channel.lastMessage = dto
            }
            if let lm = channel.lastMessage?.createdAt.bridgeDate,
               let lr = channel.lastReaction?.createdAt?.bridgeDate,
               lm > lr {
                channel.lastReaction = nil
            }
        }
        dto.replied = false
        dto.unlisted = false
        if let parent = message.parent {
            let parentMessage = MessageDTO.fetch(id: parent.id, context: self)
            if message.id > 0 {
                let isReplied = parentMessage?.replied
                if let parentMessage {
                    dto.parent = parentMessage
                } else {
                    dto.parent = createOrUpdate(message: parent, channelId: channelId)
                }
                if isReplied == nil || isReplied == true {
                    dto.parent?.replied = true
                } else {
                    dto.parent?.replied = false
                }
            } else {
                dto.parent = parentMessage
            }
        } else if message.state == .deleted {
            dto.parent = nil
        }
        ReactionDTO.unownedReactions(messageId: message.id, context: self)
            .forEach { $0.message = dto }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(messages: [Message], channelId: ChannelId) -> [MessageDTO] {
        messages.map { createOrUpdate(message: $0, channelId: channelId) }
    }
    
    @discardableResult
    public func update(message: Message, channelId: ChannelId) -> MessageDTO? {
        if MessageDTO.fetch(tid: Int64(message.tid), context: self) != nil {
            return createOrUpdate(message: message, channelId: channelId)
        }
        if MessageDTO.fetch(id: message.id, context: self) != nil {
            return createOrUpdate(message: message, channelId: channelId)
        }
        return nil
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
        guard let dto = MessageDTO.fetch(request: request, context: self).first,
              !dto.isDeleted
        else { return nil }
        
        // Attachment
        attachments?.forEach {
            var attachmentDTO: AttachmentDTO?
            if $0.id != 0 {
                attachmentDTO = AttachmentDTO.fetch(id: $0.id, context: self)
                logger.verbose("[AttachmentDTO] update MESSAGE found by id \($0.id) \(attachmentDTO != nil) \($0.description)")
            } else if $0.tid != 0 {
                attachmentDTO = AttachmentDTO.fetch(tid: $0.tid, message: dto, context: self)
                logger.verbose("[AttachmentDTO] update MESSAGE found by tid \($0.tid) \(attachmentDTO != nil) \($0.description)")
            } else if let filePath = $0.filePath {
                attachmentDTO = AttachmentDTO.fetchOrCreate(filePath: filePath, message: dto, context: self)
                logger.verbose("[AttachmentDTO] update MESSAGE found by filePath \(filePath) \(attachmentDTO != nil) \($0.description)")
            } else if let url = $0.url {
                logger.verbose("[AttachmentDTO] update MESSAGE found by url \(url) \(attachmentDTO != nil) \($0.description)")
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
            attachmentDTO.metadata = $0.metadata
            attachmentDTO.channelId = Int64(chatMessage.channelId)
            attachmentDTO.uploadedFileSize = Int64($0.uploadedFileSize)
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(attachments: [Attachment], dto: MessageDTO) -> MessageDTO {
        dto.attachments = .init(
            attachments.compactMap {
                var attachmentDTO: AttachmentDTO?
                if let url = $0.url {
                    attachmentDTO = AttachmentDTO.fetch(url: url, message: dto, context: self)
                }
                if attachmentDTO == nil {
                    if $0.tid != 0 {
                        attachmentDTO = AttachmentDTO.fetch(tid: Int64($0.tid), message: dto, context: self)
                    } else if $0.id != 0 {
                        attachmentDTO = AttachmentDTO.fetchOrCreate(id: $0.id, context: self)
                    }
                }
                if attachmentDTO == nil, let url = $0.url {
                    attachmentDTO = AttachmentDTO.fetchOrCreate(url: url, message: dto, context: self)
                }
                if attachmentDTO == nil {
                    attachmentDTO = AttachmentDTO.create(context: self)
                }
                attachmentDTO = attachmentDTO?.map($0)
                attachmentDTO?.channelId = dto.channelId
                return attachmentDTO
            })
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(attachment: Attachment, channelId: ChannelId) -> AttachmentDTO {
        logger.verbose("[AttachmentDTO] createOrUpdate by channelId \(channelId) create \(attachment.description)")
        let dto = AttachmentDTO.fetchOrCreate(id: attachment.id, context: self).map(attachment)
        dto.channelId = Int64(channelId)
        if dto.message == nil {
            dto.message = MessageDTO.fetch(id: attachment.messageId, context: self)
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(attachments: [Attachment], channelId: ChannelId) -> [AttachmentDTO] {
        attachments.map { createOrUpdate(attachment: $0, channelId: channelId) }
    }
    
    @discardableResult
    public func createOrUpdate(userReactions: [Reaction], dto: MessageDTO) -> MessageDTO {
        if dto.userReactions == nil {
            dto.userReactions = []
        }
        
        var items = dto.userReactions?.compactMap { !$0.pending ? $0 : nil } ?? []
        items.removeAll(where: { r in userReactions.contains(where: { $0.key == r.key }) })
        dto.userReactions?.subtract(items)
        let newItems = createOrUpdate(reactions: userReactions)
            .map {
                $0.messageSelf = dto
                return $0
            }
        dto.userReactions?.formUnion(newItems)
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(reactions: [Reaction]) -> [ReactionDTO] {
        reactions.compactMap {
            let rdto = ReactionDTO.fetchOrCreate(userId: $0.user.id, key: $0.key, messageId: $0.messageId, context: self).map($0)
            rdto.user = createOrUpdate(user: $0.user)
            if let message = MessageDTO.fetch(id: $0.messageId, context: self) {
                rdto.message = message
                if !message.incoming,
                   let channel = ChannelDTO.fetch(id: ChannelId(message.channelId), context: self) {
                    if channel.lastReaction == nil {
                        channel.lastReaction = rdto
                    } else if channel.lastReaction!.id < rdto.id {
                        channel.lastReaction = rdto
                    }
                }
            } else {
                rdto.message = nil
            }
            return rdto
        }
    }
    
    @discardableResult
    public func add(reaction: Reaction) -> ReactionDTO? {
        guard let message = MessageDTO.fetch(id: reaction.messageId, context: self)
        else { return nil }
        let rdto = ReactionDTO.fetchOrCreate(userId: reaction.user.id, key: reaction.key, messageId: reaction.messageId, context: self).map(reaction)
        rdto.user = createOrUpdate(user: reaction.user)
        if let rTotalDto = ReactionTotalDTO.fetch(messageId: reaction.messageId, key: reaction.key, context: self) {
            rTotalDto.count += 1
            rTotalDto.score += Int64(reaction.score)
        } else {
            let rTotalDto = ReactionTotalDTO.insertNewObject(into: self)
            rTotalDto.count = 1
            rTotalDto.score = Int64(reaction.score)
            rTotalDto.key = reaction.key
            message.reactionTotal?.insert(rTotalDto)
        }
        
        rdto.message = message
        if !message.incoming,
           let channel = ChannelDTO.fetch(id: ChannelId(message.channelId), context: self)
        {
            if channel.lastReaction == nil {
                channel.lastReaction = rdto
            } else if channel.lastReaction!.id < rdto.id {
                channel.lastReaction = rdto
            }
        }
        return rdto
    }
    
    @discardableResult
    public func delete(reaction: Reaction) -> ReactionDTO? {
        var channelDto: ChannelDTO?
        if let dto = ReactionDTO.fetch(userId: reaction.user.id, key: reaction.key, messageId: reaction.messageId, context: self) {
            if let messageDto = MessageDTO.fetch(id: reaction.messageId, context: self) {
                channelDto = ChannelDTO.fetch(id: ChannelId(messageDto.channelId), context: self)
                messageDto.userReactions?.remove(dto)
                messageDto.pendingReactions?.remove(dto)
                if let total = messageDto.reactionTotal?.first(where: { $0.key == reaction.key }) {
                    total.count = max(0, total.count - 1)
                    total.score = max(0, total.score - Int64(reaction.score))
                    if total.count == 0 {
                        messageDto.reactionTotal?.remove(total)
                    }
                }
            }
            delete(dto)
            if let channelDto,
               channelDto.lastReaction?.id ?? 0 == reaction.id {
                let predicate = NSPredicate(format: "id != %lld AND message.incoming = false AND message.channelId == %lld", reaction.id, channelDto.id)
                channelDto.lastReaction = ReactionDTO.lastReaction(predicate: predicate, context: self)
            }
            return dto
        }
        return nil
    }
    
    @discardableResult
    public func createOrUpdate(reactionTotal: [ReactionTotal], dto: MessageDTO, deleteNotExistReactions: Bool) -> MessageDTO {
        reactionTotal.forEach {
            let rdto = ReactionTotalDTO.fetchOrCreate(messageId: MessageId(dto.id), key: $0.key, context: self).map($0)
            rdto.message = dto
        }
        if deleteNotExistReactions {
            let keys = reactionTotal.map { $0.key }
            let request = ReactionTotalDTO.fetchRequest()
            request.predicate = NSPredicate(format: "message.id == %lld AND (NOT (key IN %@))", dto.id, keys)
            let rdDtos = ReactionTotalDTO.fetch(request: request, context: self)
            rdDtos.forEach {
                delete($0)
            }
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(requestedMentionUserIds: [UserId], dto: MessageDTO) -> MessageDTO {
        dto.orderedMentionedUserIds = requestedMentionUserIds
        dto.mentionedUsers = .init(
            requestedMentionUserIds.compactMap {
                UserDTO.fetch(id: $0, context: self)
            })
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(mentionedUsers: [User], dto: MessageDTO) -> MessageDTO {
        dto.orderedMentionedUserIds = mentionedUsers.map { $0.id }
        dto.mentionedUsers = .init(
            mentionedUsers.map {
                createOrUpdate(user: $0)
            })
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(userMarkers: [Marker], dto: MessageDTO) -> MessageDTO {
        guard !userMarkers.isEmpty else { return dto }
        if dto.userMarkers == nil {
            dto.userMarkers = .init()
        }
        
        for marker in userMarkers {
            let markerDTO = MarkerDTO.fetchOrCreate(messageId: MessageId(dto.id), name: marker.name, userId: marker.user.id, context: self).map(marker)
            markerDTO.user = UserDTO.fetchOrCreate(id: marker.user.id, context: self).map(marker.user)
            dto.userMarkers?.insert(markerDTO)
            dto.pendingMarkerNames?.remove(marker.name)
        }
        if dto.pendingMarkerNames != nil, dto.pendingMarkerNames!.isEmpty {
            dto.pendingMarkerNames = nil
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
    public func createOrUpdate(bodyAttributes: [Message.BodyAttribute]?, dto: MessageDTO) -> MessageDTO {
        guard let bodyAttributes, !bodyAttributes.isEmpty else {
            dto.bodyAttributes = []
            return dto
        }
        if dto.bodyAttributes == nil {
            dto.bodyAttributes = .init()
        }
        
        let oldBodyAttributes = dto.bodyAttributes!
        oldBodyAttributes.forEach { oldBodyAttribute in
            if !bodyAttributes.contains(where: {
                $0.offset == oldBodyAttribute.offset
                    && $0.length == oldBodyAttribute.length
                    && $0.type == oldBodyAttribute.type
            }) {
                delete(oldBodyAttribute)
            }
        }
        for bodyAttribute in bodyAttributes {
            var bodyAttributeDTO: BodyAttributeDTO! = dto.bodyAttributes?.first(where: {
                $0.offset == bodyAttribute.offset
                    && $0.length == bodyAttribute.length
                    && $0.type == bodyAttribute.type
            })
            if bodyAttributeDTO == nil {
                bodyAttributeDTO = BodyAttributeDTO.insertNewObject(into: self).map(bodyAttribute)
            }
            bodyAttributeDTO.message = dto
            dto.bodyAttributes?.insert(bodyAttributeDTO)
        }
        return dto
    }
    
    @discardableResult
    public func add(linkMetadatas: [LinkMetadata], messageId: MessageId) -> MessageDTO? {
        guard let dto = MessageDTO.fetch(id: messageId, context: self)
        else { return nil }
        add(linkMetadatas: linkMetadatas, dto: dto)
        return dto
    }
    
    @discardableResult
    public func add(linkMetadatas: [LinkMetadata], messageTid: Int64) -> MessageDTO? {
        guard let dto = MessageDTO.fetch(tid: messageTid, context: self)
        else { return nil }
        add(linkMetadatas: linkMetadatas, dto: dto)
        return dto
    }
    
    public func add(linkMetadatas: [LinkMetadata], dto: MessageDTO) {
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
            dto.linkMetadatas = links
//            dto.linkMetadatas?.formUnion(links)
        }
    }
    
    @discardableResult
    public func createOrUpdate(marker: Marker, messageId: MessageId) -> MarkerDTO {
        MarkerDTO.fetchOrCreate(messageId: messageId, name: marker.name, userId: marker.user.id, context: self).map(marker)
    }
    
    @discardableResult
    public func createOrUpdate(markers: [Marker], messageId: MessageId) -> [MarkerDTO] {
        markers.map {
            let markerDTO = MarkerDTO.fetchOrCreate(messageId: messageId, name: $0.name, userId: $0.user.id, context: self).map($0)
            markerDTO.user = UserDTO.fetchOrCreate(id: $0.user.id, context: self).map($0.user)
            return markerDTO
        }
    }
    
    @discardableResult
    public func createOrUpdate(messageMarkers: MessageListMarker) -> [MessageDTO] {
        let predicate = NSPredicate(format: "id IN %@",
                                    messageMarkers.messageIds.map { MessageId($0.uint64Value) })
        let messages = MessageDTO.fetch(
            predicate: predicate,
            context: self
        )
        
        messages.forEach {
            let markerDTO = MarkerDTO.fetchOrCreate(
                messageId: MessageId($0.id),
                name: messageMarkers.name,
                userId: messageMarkers.user.id,
                context: self
            )
            markerDTO.createdAt = messageMarkers.createdAt.bridgeDate
            markerDTO.user = UserDTO.fetchOrCreate(id: messageMarkers.user.id, context: self).map(messageMarkers.user)
        }
        return messages
    }
    
    @discardableResult
    public func update(messageMarkers: MessageListMarker) -> [MessageDTO] {
        guard let status = ChatMessage.DeliveryStatus(rawValue: messageMarkers.name) else {
            return update(customMessageMarkers: messageMarkers)
        }
        guard !messageMarkers.messageIds.isEmpty else { return [] }
        let maxId = messageMarkers.messageIds.max(by: { $0.int64Value < $1.int64Value }) ?? messageMarkers.messageIds.last!
        guard let channelId = MessageDTO.fetch(id: MessageId(maxId.int64Value), context: self)?.channelId
        else { return [] }
        let predicate = NSPredicate(
            format: "channelId == %lld AND id <= %@ AND deliveryStatus != %d AND deliveryStatus != %d AND deliveryStatus < %d AND incoming == false",
            channelId,
            maxId,
            ChatMessage.DeliveryStatus.pending.intValue,
            ChatMessage.DeliveryStatus.failed.intValue,
            status.intValue
        )
        
        let messages = MessageDTO.fetch(
            predicate: predicate,
            context: self
        )

        messages.forEach {
            $0.deliveryStatus = Int16(status.preferredStatus(for: Int($0.deliveryStatus)).intValue)
        }
        if messageMarkers.user.id == me {
            update(messageSelfMarkers: messageMarkers)
        } else {
            createOrUpdate(messageMarkers: messageMarkers)
        }
        return messages
    }
    
    public func update(customMessageMarkers messageMarkers: MessageListMarker) -> [MessageDTO] {
        guard !messageMarkers.messageIds.isEmpty else { return [] }
        if messageMarkers.user.id == me {
            return update(messageSelfMarkers: messageMarkers)
        } else {
            return createOrUpdate(messageMarkers: messageMarkers)
        }
    }
    
    @discardableResult
    public func update(messageSelfMarkers: MessageListMarker) -> [MessageDTO] {
        let predicate = NSPredicate(format: "id IN %@",
                                    messageSelfMarkers.messageIds.map { MessageId($0.uint64Value) })
        let messages = MessageDTO.fetch(
            predicate: predicate,
            context: self
        )
        
        messages.forEach {
            if $0.userMarkers == nil {
                $0.userMarkers = .init()
            }
            let markerDTO = MarkerDTO.fetchOrCreate(messageId: MessageId($0.id), name: messageSelfMarkers.name, userId: messageSelfMarkers.user.id, context: self)
            markerDTO.createdAt = messageSelfMarkers.createdAt.bridgeDate
            markerDTO.user = UserDTO.fetchOrCreate(id: messageSelfMarkers.user.id, context: self).map(messageSelfMarkers.user)
            $0.userMarkers?.insert(markerDTO)
            
            if $0.markerTotal?[messageSelfMarkers.name] == nil {
                if $0.markerTotal == nil {
                    $0.markerTotal = .init()
                }
                $0.markerTotal![messageSelfMarkers.name] = 1
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
        guard !messageIds.isEmpty
        else { return [] }
        let predicate = NSPredicate(format: "id IN %@", messageIds)
        let messages = MessageDTO.fetch(
            predicate: predicate,
            context: self
        )
        
        messages.forEach {
            if $0.pendingMarkerNames == nil {
                $0.pendingMarkerNames = .init(arrayLiteral: markerName)
            } else if !$0.pendingMarkerNames!.contains(markerName) {
                $0.pendingMarkerNames!.insert(markerName)
            }
        }
        return messages
    }
    
    @discardableResult
    public func delete(messagePendingMarkers messageIds: [MessageId], markerName: String) -> [MessageDTO] {
        guard !messageIds.isEmpty
        else { return [] }
        let predicate = NSPredicate(format: "id IN %@", messageIds)
        let messages = MessageDTO.fetch(
            predicate: predicate,
            context: self
        )
        
        messages.forEach {
            if $0.pendingMarkerNames != nil {
                $0.pendingMarkerNames?.remove(markerName)
            }
        }
        return messages
    }
    
    @discardableResult
    public func addPendingReaction(messageId: MessageId, key: String, score: UInt16, reason: String?, enforceUnique: Bool) -> (MessageDTO, ReactionDTO)? {
        guard let dto = MessageDTO.fetch(id: messageId, context: self)
        else { return nil }
        if dto.pendingReactions == nil {
            dto.pendingReactions = .init()
        }
        
        let rDto: ReactionDTO
        
        let request = ReactionDTO.fetchRequest()
        request.predicate = .init(format: "pending == %d AND key = %@ AND messageId = %lld", true, key, messageId)
        if let r = ReactionDTO.fetch(request: request, context: self).first {
            rDto = r
        } else {
            rDto = ReactionDTO.insertNewObject(into: self)
        }
        rDto.id = Int64.max
        rDto.message = dto
        rDto.createdAt = Date().bridgeDate
        rDto.key = key
        rDto.score = Int32(score)
        rDto.reason = reason
        rDto.messageId = Int64(messageId)
        rDto.pending = true
        if !me.isEmpty {
            rDto.user = UserDTO.fetch(id: me, context: self)
        }
        dto.pendingReactions?.insert(rDto)
        
        if !dto.incoming,
           let channel = ChannelDTO.fetch(id: ChannelId(dto.channelId), context: self) {
            channel.lastReaction = rDto
        }
        return (dto, rDto)
    }
    
    @discardableResult
    public func removePendingReaction(messageId: MessageId, key: String) -> MessageDTO? {
        guard let dto = MessageDTO.fetch(id: messageId, context: self)
        else { return nil }
        let request = ReactionDTO.fetchRequest()
        request.predicate = NSPredicate(format: "messageId == %lld AND key == %@ AND pending == true", messageId, key)
        let rDto = ReactionDTO.fetch(request: request, context: self)
        rDto.forEach {
            dto.pendingReactions?.remove($0)
            delete($0)
        }
        return dto
    }

    public func deleteMessage(id: MessageId) {
        if let dto = MessageDTO.fetch(id: id, context: self) {
            if let channel = ChannelDTO.fetch(id: ChannelId(dto.channelId), context: self), channel.lastMessage == dto {
                let predicate = NSPredicate(format: "channelId == %lld AND id != %lld", channel.id, id)
                channel.lastMessage = MessageDTO.lastMessage(predicate: predicate, context: self)
                
                if let lastMessage = channel.lastMessage,
                   lastMessage.id != 0
                {
                    let reactionPredicate = NSPredicate(format: "channelId == %lld AND message.incoming = false", channel.id)
                    if let lastReaction = ReactionDTO.lastReaction(predicate: reactionPredicate, context: self),
                       lastMessage.id < lastReaction.id
                    {
                        channel.lastReaction = lastReaction
                    }
                }
            }
            delete(dto)
        }
    }

    public func deleteMessage(tid: Int64) {
        if let dto = MessageDTO.fetch(tid: tid, context: self) {
            if let channel = ChannelDTO.fetch(id: ChannelId(dto.channelId), context: self), channel.lastMessage == dto {
                let predicate = NSPredicate(format: "channelId == %lld AND tid != %lld", channel.id, tid)
                channel.lastMessage = MessageDTO.lastMessage(predicate: predicate, context: self)
                
                if let lastMessage = channel.lastMessage,
                   lastMessage.id != 0
                {
                    let reactionPredicate = NSPredicate(format: "channelId == %lld AND message.incoming = false", channel.id)
                    if let lastReaction = ReactionDTO.lastReaction(predicate: reactionPredicate, context: self),
                       lastMessage.id < lastReaction.id
                    {
                        channel.lastReaction = lastReaction
                    }
                }
            }
            delete(dto)
        }
    }
    
    public func deleteReaction(id: ReactionId) {
        if let dto = ReactionDTO.fetch(id: id, context: self) {
            let messageDto = MessageDTO.fetch(id: MessageId(dto.messageId), context: self)
            messageDto?.userReactions?.remove(dto)
            messageDto?.pendingReactions?.remove(dto)
            delete(dto)
            if let messageDto, let channelDto = ChannelDTO.fetch(id: ChannelId(messageDto.channelId), context: self),
               channelDto.lastReaction?.id ?? 0 == id
            {
                let predicate = NSPredicate(format: "id != %lld AND message.incoming = false AND message.channelId == %@", id, channelDto.id)
                channelDto.lastReaction = ReactionDTO.lastReaction(predicate: predicate, context: self)
            }
        }
    }
    
    public func deleteNotExistReactions(_ reactions: [Reaction]) {
        let group = Dictionary(grouping: reactions) { $0.messageId }
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: ReactionDTO.entityName)
        for item in group {
            fetchRequest.predicate = .init(format: "messageId == %lld AND (NOT (id IN %@))", item.key, item.value.map { $0.id })
            try? batchDelete(fetchRequest: fetchRequest)
        }
    }
    
    public func deleteAttachmentsFor(messageId: MessageId) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: AttachmentDTO.entityName)
        fetchRequest.predicate = .init(format: "messageId == %lld", messageId)
        try? batchDelete(fetchRequest: fetchRequest)
    }
    
    public func deleteAttachmentsFor(messageTid: Int64) {
        if let attachments = MessageDTO.fetch(tid: messageTid, context: self)?.attachments {
            for attachment in attachments {
                delete(attachment)
            }
        }
    }
    
    public func deleteAttachmentsFor(message: Message) {
        if message.deliveryStatus == .pending ||
            message.deliveryStatus == .failed
        {
            deleteAttachmentsFor(messageTid: Int64(message.tid))
        } else {
            deleteAttachmentsFor(messageId: message.id)
        }
    }
    
    public func deleteAttachment(id: AttachmentId) {
        if let attachment = AttachmentDTO.fetch(id: id, context: self) {
            delete(attachment)
        }
    }
    
    public func updateAttachment(with filePath: String, chatMessage: ChatMessage, attachment: ChatMessage.Attachment) {
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
        else { return }
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        guard let dto = MessageDTO.fetch(request: request, context: self).first,
              !dto.isDeleted
        else { return }
        
        guard let attachmentDTO = AttachmentDTO.fetch(filePath: filePath, message: dto, context: self).first
        else { return }
        attachmentDTO.transferProgress = attachment.transferProgress
        attachmentDTO.status = attachment.status.rawValue
        attachmentDTO.name = attachment.name
        attachmentDTO.metadata = attachment.metadata
        attachmentDTO.channelId = Int64(chatMessage.channelId)
        attachmentDTO.uploadedFileSize = Int64(attachment.uploadedFileSize)
        attachmentDTO.filePath = attachment.filePath
    }

    public func deleteAllMessages(
        channelId: ChannelId,
        before date: Date? = nil
    ) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: MessageDTO.entityName)
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        var predicate = NSPredicate(format: "channelId == %lld", channelId)
        if let date {
            predicate = NSCompoundPredicate(type: .and, subpredicates: [
                predicate,
                NSPredicate(format: "createdAt <= %@", date as NSDate)
            ])
        }
        request.predicate = predicate
        try batchDelete(fetchRequest: request)
        try? deleteAllAttachments(channelId: channelId, before: date)
        if let date,
           let channel = ChannelDTO.fetch(id: channelId, context: self)
        {
            if let lastMessage = channel.lastMessage {
                if date >= lastMessage.createdAt.bridgeDate {
                    channel.lastMessage = nil
//                    channel.messages = nil
                    channel.lastReceivedMessageId = 0
                    channel.lastDisplayedMessageId = 0
                }
            } else {
                channel.lastReceivedMessageId = 0
                channel.lastDisplayedMessageId = 0
            }
        }
    }
    
    public func deleteAllAttachments(
        channelId: ChannelId,
        before date: Date? = nil
    ) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: AttachmentDTO.entityName)
        request.sortDescriptor = NSSortDescriptor(keyPath: \AttachmentDTO.id, ascending: false)
        var predicate = NSPredicate(format: "channelId == %lld", channelId)
        if let date {
            predicate = NSCompoundPredicate(type: .and, subpredicates: [
                predicate,
                NSPredicate(format: "createdAt <= %@", date as NSDate)
            ])
        }
        request.predicate = predicate
        try batchDelete(fetchRequest: request)
    }
    
    @discardableResult
    public func createOrUpdate(notificationContent userInfo: [AnyHashable: Any]) throws -> MessageDTO? {
        let pushData = try NotificationPayload(from: userInfo)
        
        if let reaction = pushData.reaction,
           reaction.key != ""
        {
            return createOrUpdateReaction(pushData: pushData)?.message
        }
        
        if let message = pushData.message,
           let channel = pushData.channel,
           let messageId = MessageId(message.id),
           let channelId = ChannelId(channel.id)
        {
            let dto = MessageDTO.fetchOrCreate(id: messageId, context: self).map(message)
            dto.tid = Int64(messageId)
            dto.channelId = Int64(channelId)
            
            if let user = pushData.user {
                dto.user = createOrUpdate(user: user)
            }
            
            if let mentionedUsers = message.mentionedUsers,
               !mentionedUsers.isEmpty
            {
                createOrUpdate(mentionedUsers: mentionedUsers, dto: dto)
            }
            
            if let attachments = message.attachments,
               !attachments.isEmpty
            {
                createOrUpdate(attachments: attachments, dto: dto)
            }
            
            if let forwardingDetails = message.forwardingDetails {
                createOrUpdate(forwardDetail: forwardingDetails, dto: dto)
            }
            
            if dto.markerTotal == nil {
                dto.markerTotal = .init()
            }
            
            if let channel = ChannelDTO.fetch(id: ChannelId(dto.channelId), context: self) {
                channel.newMessageCount += 1
                if let lastMessage = channel.lastMessage {
                    if lastMessage.id != 0 && dto.id != 0 {
                        if lastMessage.id <= dto.id {
                            channel.lastMessage = dto
                        }
                    } else if lastMessage.createdAt.bridgeDate < dto.createdAt.bridgeDate {
                        channel.lastMessage = dto
                    }
                } else {
                    channel.lastMessage = dto
                }
                if let lm = channel.lastMessage?.createdAt.bridgeDate,
                   let lr = channel.lastReaction?.createdAt?.bridgeDate,
                   lm > lr
                {
                    channel.lastReaction = nil
                }
            }
            
            if let parentId = message.parentId,
               let id = Int64(parentId),
               id > 0,
               let message = MessageDTO.fetch(id: MessageId(id), context: self)
            {
                dto.parent = message
            }
            
            dto.replied = false
            dto.unlisted = false
            return dto
        }
        return nil
    }
    
    @discardableResult
    func createOrUpdate(mentionedUsers: [NotificationPayload.User], dto: MessageDTO) -> MessageDTO {
        dto.orderedMentionedUserIds = mentionedUsers.map { $0.id }
        dto.mentionedUsers = .init(
            mentionedUsers.map {
                createOrUpdate(user: $0)
            })
        return dto
    }
    
    @discardableResult
    func createOrUpdate(user: NotificationPayload.User) -> UserDTO {
        UserDTO.fetchOrCreate(id: user.id, context: self).map(user)
    }
    
    @discardableResult
    func createOrUpdate(attachments: [NotificationPayload.Message.Attachment], dto: MessageDTO) -> MessageDTO {
        dto.attachments = .init(
            attachments.compactMap {
                let attachmentDTO = AttachmentDTO.fetchOrCreate(url: $0.data, message: dto, context: self).map($0, dto: dto)
                attachmentDTO.channelId = dto.channelId
                return attachmentDTO
            })
        return dto
    }
    
    @discardableResult
    func createOrUpdate(forwardDetail: NotificationPayload.Message.ForwardingDetails, dto: MessageDTO) -> MessageDTO {
        guard let messageId = Int64(forwardDetail.messageId),
              let channelId = Int64(forwardDetail.channelId)
        else {
            return dto
        }
        dto.forwardMessageId = messageId
        dto.forwardUser = UserDTO.fetchOrCreate(id: forwardDetail.userId, context: self)
        if dto.deliveryStatus == ChatMessage.DeliveryStatus.pending.intValue {
            if let message = MessageDTO.fetch(id: MessageId(messageId), context: self) {
                dto.forwardChannelId = message.channelId
                dto.forwardHops = 0
            }
        } else {
            dto.forwardChannelId = channelId
            dto.forwardHops = Int64(forwardDetail.hops)
        }
        return dto
    }
    
    func createOrUpdateReaction(pushData: NotificationPayload) -> ReactionDTO? {
        guard let reaction = pushData.reaction,
              let message = pushData.message,
              let user = pushData.user,
              let messageId = MessageId(message.id)
        else { return nil }
        guard let messageDTO = MessageDTO.fetch(id: messageId, context: self)
        else { return nil }
        let rdto = ReactionDTO.fetchOrCreate(userId: user.id, key: reaction.key, messageId: messageId, context: self)
        rdto.user = createOrUpdate(user: user)
        rdto.message = messageDTO
        if let message = rdto.message,
           !message.incoming,
           let channel = ChannelDTO.fetch(id: ChannelId(message.channelId), context: self)
        {
            if channel.lastReaction == nil {
                channel.lastReaction = rdto
            } else if channel.lastReaction!.id < rdto.id {
                channel.lastReaction = rdto
            }
        }
        return rdto
    }
    
    // MARK: Checksum
    
    @discardableResult
    public func createOrUpdate(checksum: ChatMessage.Attachment.Checksum) -> ChecksumDTO {
        let dto = ChecksumDTO.fetchOrCreate(checksum: checksum.checksum, context: self).map(checksum)
        return dto
    }
    
    @discardableResult
    public func updateChecksum(data: String, messageTid: Int64, attachmentTid: Int64) -> ChecksumDTO? {
        let dto = ChecksumDTO.fetch(message: messageTid, attachmentTid: attachmentTid, context: self)
        dto?.data = data
        return dto
    }
}
