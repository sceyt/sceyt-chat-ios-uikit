//
//  ChannelDatabaseSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

public protocol ChannelDatabaseSession {
    
    @discardableResult
    func createOrUpdate(channel: Channel) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(channel: ChatChannel) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(channels: [Channel]) -> [ChannelDTO]
    
    func markAsRead(channelId: ChannelId)
    
    @discardableResult
    func add(members: [Member], channelId: ChannelId) -> ChannelDTO?
    
    @discardableResult
    func update(owner: Member, channelId: ChannelId) -> ChannelDTO
    
    @discardableResult
    func createOrUpdate(member: Member, channelId: ChannelId) -> MemberDTO
    
    @discardableResult
    func createOrUpdate(members: [Member], channelId: ChannelId) -> [MemberDTO]
    
    @discardableResult
    func createOrUpdate(member: ChatChannelMember, channelId: ChannelId) -> MemberDTO
    
    func delete(members: [Member], channelId: ChannelId)
    
    func deleteMember(id: UserId, from channelId: ChannelId)
    
    func updateChannelDTOs(for userId: UserId)
    
    @discardableResult
    func update(draft message: NSAttributedString?, date: Date?, channelId: ChannelId) -> ChannelDTO?
}

extension NSManagedObjectContext: ChannelDatabaseSession {
    
    @discardableResult
    public func createOrUpdate(channel: Channel) -> ChannelDTO {
        return createOrUpdate(channel: channel, forceUpdate: false)
    }
    
    @discardableResult
    public func createOrUpdate(channel: Channel, forceUpdate: Bool) -> ChannelDTO {
        let (channelDTO, created) = ChannelDTO.fetchOrCreate(id: channel.id, context: self)
        return apply(channel: channel, to: channelDTO, created: created, forceUpdate: forceUpdate)
    }

    @discardableResult
    private func apply(channel: Channel, to channelDTO: ChannelDTO, created: Bool, forceUpdate: Bool) -> ChannelDTO {
        let dto = channelDTO.map(channel)

        if channel.newMessageCount > 0 {
            dto.newMessageCount = max(0, Int64(channel.newMessageCount) - numberOfLocallyDisplayedMessages(channelId: Int64(channel.id), above: Int64(channel.lastDisplayedMessageId)))
        }

        if let createBy = channel.createdBy {
            dto.createdBy = createOrUpdate(user: createBy)
        }

        var lastReaction: ReactionDTO?
        if let reactions = channel.lastReactions {
            let reactionDTOs = createOrUpdate(reactions: reactions)
            lastReaction = reactionDTOs.max(by: { $0.id < $1.id })
            if dto.lastReaction == nil {
                dto.lastReaction = lastReaction
            } else if let lid = dto.lastReaction?.id,
                let nlid = lastReaction?.id,
                nlid != lid {
                dto.lastReaction = lastReaction
            }
        } else {
            dto.lastReaction = nil
        }

        if created || forceUpdate {
            if let message = channel.lastMessage {
                createOrUpdate(message: message, channelId: channel.id)
            }
        }

        if let messages = channel.messages {
            createOrUpdate(messages: messages, channelId: channel.id)
        }

        if let members = channel.members {
            createOrUpdate(members: members, channelId: channel.id)
        }

        if let role = channel.userRole {
            dto.userRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }

        if let messagesClearedAt = channel.messagesClearedAt {
            try? deleteAllMessages(
                channelId: channel.id,
                before: messagesClearedAt
            )
        }
        return dto
    }

    @discardableResult
    public func createOrUpdateByURI(channel: Channel) -> ChannelDTO {
        let dto = (ChannelDTO.fetchChannelByURI(channel: ChatChannel(channel: channel), context: self) ?? (ChannelDTO.fetchOrCreate(id: channel.id, context: self)).0.map(channel))
        
        dto.id = Int64(channel.id)
        
        if channel.newMessageCount > 0 {
            dto.newMessageCount = max(0, Int64(channel.newMessageCount) - numberOfLocallyDisplayedMessages(channelId: Int64(channel.id), above: Int64(channel.lastDisplayedMessageId)))
        }
        if let createBy = channel.createdBy {
            dto.createdBy = createOrUpdate(user: createBy)
        }
        
        var lastReaction: ReactionDTO?
        if let reactions = channel.lastReactions {
            let reactionDTOs = createOrUpdate(reactions: reactions)
            lastReaction = reactionDTOs.max(by: { $0.id < $1.id })
            if dto.lastReaction == nil {
                dto.lastReaction = lastReaction
            } else if let lid = dto.lastReaction?.id,
                      let nlid = lastReaction?.id,
                      nlid != lid {
                dto.lastReaction = lastReaction
            }
        } else {
            dto.lastReaction = nil
        }
        
        
        if let message = channel.lastMessage {
            createOrUpdate(message: message, channelId: channel.id)
        }
        
        if let messages = channel.messages {
            createOrUpdate(messages: messages, channelId: channel.id)
        }
        if let members = channel.members {
            createOrUpdate(members: members, channelId: channel.id)
        }
        
        if let role = channel.userRole {
            dto.userRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }
        if let messagesClearedAt = channel.messagesClearedAt {
            try? deleteAllMessages(
                channelId: channel.id,
                before: messagesClearedAt
            )
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(channel: ChatChannel) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channel.id, context: self).0.map(channel)
        if channel.newMessageCount > 0 {
            dto.newMessageCount = max(0, Int64(channel.newMessageCount) - numberOfLocallyDisplayedMessages(channelId: Int64(channel.id), above: Int64(channel.lastDisplayedMessageId)))
        }
        
        if let members = channel.members {
            for member in members {
                let mdto = createOrUpdate(member: member, channelId: channel.id)
                if mdto.channel !== dto {
                    mdto.channel = dto
                }
            }
        }
        
        if let role = channel.userRole {
            dto.userRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(channels: [Channel]) -> [ChannelDTO] {
        guard !channels.isEmpty else { return [] }

        let ids = channels.map { $0.id }
        var dtosById: [Int64: ChannelDTO] = Dictionary(
            uniqueKeysWithValues: ChannelDTO.fetch(ids: ids, context: self).map { ($0.id, $0) }
        )

        return channels.map { channel in
            let key = Int64(channel.id)
            if let existing = dtosById[key] {
                return apply(channel: channel, to: existing, created: false, forceUpdate: true)
            }
            let new = ChannelDTO.insertNewObject(into: self)
            new.id = key
            dtosById[key] = new
            return apply(channel: channel, to: new, created: true, forceUpdate: true)
        }
    }
    
    public func markAsRead(channelId: ChannelId) {
        let request = MessageDTO.fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MessageDTO.id, ascending: false)
        request.predicate = .init(
            format: "channelId == %lld AND incoming == true AND (deliveryStatus == %d OR deliveryStatus == %d)",
            channelId,
            ChatMessage.DeliveryStatus.sent.intValue,
            ChatMessage.DeliveryStatus.received.intValue
        )
        MessageDTO.fetch(request: request, context: self)
            .forEach {
                $0.deliveryStatus = Int16(ChatMessage.DeliveryStatus.displayed.intValue)
            }
    }
    
    public func deleteChannel(id: ChannelId) {
        try? deleteAllMessages(channelId: id)
        ChannelSyncStateDTO.delete(channelId: id, context: self)
        // Their messages are gone, so retrying these would only fail with `channelNotExists`.
        PendingMessageDeleteDTO.deleteAll(channelId: id, context: self)
        if let dto = ChannelDTO.fetch(id: id, context: self) {
            let deletedObjects: [AnyHashable: Any] = [
                NSDeletedObjectsKey: [dto.objectID]
            ]
            delete(dto)
            mergeChangesWithViewContext(fromRemoteContextSave: deletedObjects)
        }
    }
    
    @discardableResult
    public func add(members: [Member], channelId: ChannelId) -> ChannelDTO? {
        guard let dto = ChannelDTO.fetch(id: channelId, context: self)
        else { return nil }
        members.forEach { member in
            let memberDto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self).map(member)
            memberDto.user = createOrUpdate(user: member)
            memberDto.role = RoleDTO.fetchOrCreate(name: member.role, context: self)
        }
        
        return dto
    }
    
    @discardableResult
    public func update(owner: Member, channelId: ChannelId) -> ChannelDTO {
        let (dto, _) = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        dto.owner = MemberDTO.fetchOrCreate(id: owner.id, channelId: channelId, context: self)
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(member: Member, channelId: ChannelId) -> MemberDTO {
        let dto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self).map(member)
        dto.user = createOrUpdate(user: member)
        if !member.id.isEmpty {
            dto.role = RoleDTO.fetchOrCreate(name: member.role, context: self)
        } else {
            dto.role = nil
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(member: ChatChannelMember, channelId: ChannelId) -> MemberDTO {
        let dto = MemberDTO.fetchOrCreate(id: member.id, channelId: channelId, context: self)
        dto.user = createOrUpdate(user: member)
        if !member.id.isEmpty, let role = member.roleName {
            dto.role = RoleDTO.fetchOrCreate(name: role, context: self)
        } else {
            dto.role = nil
        }
        return dto
    }
    
    @discardableResult
    public func createOrUpdate(members: [Member], channelId: ChannelId) -> [MemberDTO] {
        members.map { createOrUpdate(member: $0, channelId: channelId) }
    }
    
    public func delete(members: [Member], channelId: ChannelId) {
        guard let channel = ChannelDTO.fetch(id: channelId, context: self)
        else { return }
        let toDelete = members.compactMap {
            MemberDTO.fetch(id: $0.id, channelId: channelId, context: self)
        }
        toDelete
            .forEach {
                delete($0)
            }
    }
    
    public func deleteMember(id: UserId, from channelId: ChannelId) {
        if let member = MemberDTO.fetch(id: id, channelId: channelId, context: self) {
            delete(member)
        }
    }
    
    public func updateChannelDTOs(for userId: UserId) {
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: MemberDTO.entityName)
        fetchRequest.predicate = NSPredicate(format: "user.id == %@", userId)
        fetchRequest.propertiesToFetch = ["channelId"]
        fetchRequest.resultType = .dictionaryResultType
        
        if let results = MemberDTO.fetch(request: fetchRequest, context: self) as? [[String: Int64]] {
            let channelIds = results.compactMap { $0.values.first.map { ChannelId($0) }}
            let fetchRequest = ChannelDTO.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "(type == %@) AND (id IN %@)", SceytChatUIKit.shared.config.channelTypesConfig.direct, channelIds)
            let channels = ChannelDTO.fetch(request: fetchRequest, context: self)
            channels.forEach { dto in
                dto.toggle.toggle()
            }
        }
    }
    
    @discardableResult
    public func update(draft message: NSAttributedString?, date: Date? = nil, channelId: ChannelId) -> ChannelDTO? {
        let dto = ChannelDTO.fetch(id: channelId, context: self)
        dto?.draft = message
        dto?.draftDate = date?.bridgeDate
        return dto
    }
    
    internal func deleteMembers(predicate: NSPredicate) {
        // Must delete through the context, not NSBatchDeleteRequest: role rows
        // (RoleDTO) are shared across all channels, and a batch delete leaves
        // dangling references to the removed members in the materialized
        // RoleDTO.members inverse. The next save that touches that role then
        // traps in _forceRegisterLostFault (EXC_BREAKPOINT).
        let request = MemberDTO.fetchRequest()
        request.predicate = predicate
        MemberDTO.fetch(request: request, context: self)
            .forEach {
                delete($0)
            }
    }
    
    /// Optimistically drops the channel's unread count when "displayed" markers are
    /// stored locally, so the badge doesn't wait for the server's unread-count push
    /// (which lags on slow connections and never arrives offline).
    internal func applyOptimisticDisplayed(channelId: Int64, newlyDisplayed: [MessageDTO]) {
        guard let dto = ChannelDTO.fetch(id: ChannelId(channelId), context: self),
              dto.newMessageCount > 0,
              let maxId = newlyDisplayed.map({ $0.id }).max()
        else { return }
        if let lastMessageId = dto.lastMessage?.id, maxId >= lastMessageId {
            // The server clears everything <= the displayed watermark, so displaying
            // the last message means nothing unread remains.
            dto.newMessageCount = 0
        } else {
            let countable = newlyDisplayed.filter { $0.incoming && $0.id > dto.lastDisplayedMessageId }
            dto.newMessageCount = max(0, dto.newMessageCount - Int64(countable.count))
        }
    }

    /// Counts incoming messages above the server's displayed watermark that the local
    /// user has already displayed (pending or ACKed marker). Server channel payloads
    /// can carry a count that predates those markers; subtracting this keeps a stale
    /// write from restoring an already-cleared badge. Once the server watermark passes
    /// a marked message it drops out of the count, so server values apply verbatim.
    internal func numberOfLocallyDisplayedMessages(channelId: Int64, above serverDisplayedId: Int64) -> Int64 {
        var ids = Set<Int64>()
        // pendingMarkerNames is a transformable Set — CONTAINS can't run in SQL.
        let pendingPredicate = NSPredicate(
            format: "channelId == %lld AND incoming == YES AND id > %lld AND pendingMarkerNames != nil",
            channelId, serverDisplayedId
        )
        MessageDTO.fetch(predicate: pendingPredicate, context: self)
            .filter { $0.pendingMarkerNames?.contains(DefaultMarker.displayed.rawValue) == true }
            .forEach { ids.insert($0.id) }
        if let userId = SceytChatUIKit.shared.currentUserId {
            let request = MarkerDTO.fetchRequest()
            request.predicate = NSPredicate(
                format: "name == %@ AND user.id == %@ AND messageId > %lld AND message.channelId == %lld AND message.incoming == YES",
                DefaultMarker.displayed.rawValue, userId, serverDisplayedId, channelId
            )
            MarkerDTO.fetch(request: request, context: self)
                .forEach { ids.insert($0.messageId) }
        }
        return Int64(ids.count)
    }
}
