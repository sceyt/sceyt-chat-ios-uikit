//
//  MemberDatabaseSession.swift
//  SceytChatUIKit
//

import Foundation
import CoreData
import SceytChat

 public protocol MemberDatabaseSession {

    @discardableResult
    func createOrUpdate(member: Member, channelId: ChannelId) -> MemberDTO

    @discardableResult
    func createOrUpdate(members: [Member], channelId: ChannelId) -> [MemberDTO]

    func deleteMember(id: UserId, from channelId: ChannelId)
 }

 extension NSManagedObjectContext: MemberDatabaseSession {

    @discardableResult
    public func createOrUpdate(member: Member, channelId: ChannelId) -> MemberDTO {
        let dto = MemberDTO.fetchOrCreate(id: member.id, context: self).map(member)
        dto.user = createOrUpdate(user: member)
        dto.role = RoleDTO.fetchOrCreate(name: member.role, context: self)
        let channel = ChannelDTO.fetchOrCreate(id: channelId, context: self)
        if dto.channels == nil {
            dto.channels = .init()
        }
        if member.blocked {
            dto.channels?.remove(channel)
        } else {
            dto.channels?.insert(channel)
        }
        return dto
    }

    @discardableResult
    public func createOrUpdate(members: [Member], channelId: ChannelId) -> [MemberDTO] {
        members.map { createOrUpdate(member: $0, channelId: channelId) }
    }

     public func deleteMember(id: UserId, from channelId: ChannelId) {
         if let member = MemberDTO.fetch(id: id, context: self),
            let channel = ChannelDTO.fetch(id: channelId, context: self) {
             member.channels?.remove(channel)
         }
     }
 }
