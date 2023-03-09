//
//  ChannelDatabaseSession.swift
//  SceytChatUIKit
//

import Foundation
import CoreData
import SceytChat

public protocol ChannelDatabaseSession {

    @discardableResult
    func createOrUpdate(channel: Channel) -> ChannelDTO

    @discardableResult
    func createOrUpdate(channels: [Channel]) -> [ChannelDTO]
    
    func markAsRead(channelId: ChannelId)

    @discardableResult
    func add(members: [Member], channelId: ChannelId) -> ChannelDTO

    @discardableResult
    func delete(members: [Member], channelId: ChannelId) -> ChannelDTO

    @discardableResult
    func update(owner: Member, channelId: ChannelId) -> ChannelDTO
    
    @discardableResult
    func update(draft message: NSAttributedString?, channelId: ChannelId) -> ChannelDTO?
}

extension NSManagedObjectContext: ChannelDatabaseSession {

    @discardableResult
    public func createOrUpdate(channel: Channel) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channel.id, context: self).map(channel)
        if let message = channel.lastMessage {
            createOrUpdate(message: message, channelId: channel.id)
        }
        if let lastMessage = channel.lastMessages {
            createOrUpdate(messages: lastMessage, channelId: channel.id)
        }
        if let lastActiveMembers = channel.lastActiveMembers {
            createOrUpdate(members: lastActiveMembers, channelId: channel.id)
        }
        if let direct = channel as? DirectChannel {
            dto.peer = createOrUpdate(user: direct.peer)
        }
        if let role = (channel as? GroupChannel)?.role {
            dto.currentUserRole = RoleDTO.fetchOrCreate(name: role, context: self)
        }
        if let messagesDeletionDate = channel.messagesDeletionDate {
            try? deleteAllMessages(
                channelId: channel.id,
                messagesDeletionDate: messagesDeletionDate
            )
        }
        return dto
    }

    @discardableResult
    public func createOrUpdate(channels: [Channel]) -> [ChannelDTO] {
        channels.map { createOrUpdate(channel: $0) }
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
        if let dto = ChannelDTO.fetch(id: id, context: self) {
            let deletedObjects: [AnyHashable: Any] = [
                NSDeletedObjectsKey: [dto.objectID]
            ]
            delete(dto)
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: deletedObjects,
                into: [self]
            )
        }
    }

    @discardableResult
    public func add(members: [Member], channelId: ChannelId) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        members.forEach { member in
            let memberDto = MemberDTO.fetchOrCreate(id: member.id, context: self).map(member)
            memberDto.user = createOrUpdate(user: member)
            memberDto.role = RoleDTO.fetchOrCreate(name: member.role, context: self)
            if memberDto.channels == nil {
                memberDto.channels = .init()
            }
            memberDto.channels?.insert(dto)
        }

        return dto
    }

    @discardableResult
    public func delete(members: [Member], channelId: ChannelId) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        let toDelete = members.compactMap {
            MemberDTO.fetch(id: $0.id, context: self)
        }
        toDelete.compactMap { ($0.channels == nil || $0.channels?.count == 0) ? $0 : nil }
            .forEach {
                delete($0)
            }

        return dto
    }

    @discardableResult
    public func update(owner: Member, channelId: ChannelId) -> ChannelDTO {
        let dto = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        dto.owner = MemberDTO.fetchOrCreate(id: owner.id, context: self)
        return dto
    }
    
    @discardableResult
    public func update(draft message: NSAttributedString?, channelId: ChannelId) -> ChannelDTO? {
        let dto = ChannelDTO.fetch(id: channelId, context: self)
        dto?.draft = message
        return dto
    }
}
