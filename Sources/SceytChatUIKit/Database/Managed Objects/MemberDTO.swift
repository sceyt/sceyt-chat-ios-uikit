//
//  MemberDTO+CoreDataClass.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

@objc(MemberDTO)
public class MemberDTO: NSManagedObject {

    @NSManaged public var role: RoleDTO?
    @NSManaged public var user: UserDTO?
    @NSManaged public var channel: ChannelDTO?
    @NSManaged public var channelId: Int64

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<MemberDTO> {
        return NSFetchRequest<MemberDTO>(entityName: entityName)
    }

    public static func fetch(id: UserId, channelId: ChannelId, context: NSManagedObjectContext) -> MemberDTO? {
        fetchAll(id: id, channelId: channelId, context: context).first
    }

    public static func fetchAll(id: UserId, channelId: ChannelId, context: NSManagedObjectContext) -> [MemberDTO] {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MemberDTO.user?.id, ascending: false)
        request.predicate = .init(format: "user.id == %@ AND channelId == %lld", id, channelId)
        return fetch(request: request, context: context)
    }
    
    public static func fetch(channelId: ChannelId, context: NSManagedObjectContext) -> [MemberDTO] {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MemberDTO.user?.id, ascending: false)
        request.predicate = .init(format: "channelId == %lld", channelId)
        return fetch(request: request, context: context)
    }

    public static func fetchOrCreate(id: UserId, channelId: ChannelId, context: NSManagedObjectContext) -> MemberDTO {
        let existing = fetchAll(id: id, channelId: channelId, context: context)
        if let mo = existing.first {
            if existing.count > 1 {
                existing.dropFirst().forEach { context.delete($0) }
            }
            // The relationship must always point at the channel `channelId` names.
            // When it doesn't, the channel it should point at reports members.@count == 0
            // (and is filtered out of the channel list) while another channel gets members
            // it doesn't own.
            if mo.channel?.id != Int64(channelId) {
                mo.channel = ChannelDTO.fetch(id: channelId, context: context)
            }
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.channelId = Int64(channelId)
        mo.channel = ChannelDTO.fetch(id: channelId, context: context)
        mo.user = UserDTO.fetchOrCreate(id: id, context: context)
        return mo
    }

    public func map(_ map: Member) -> MemberDTO {
        return self
    }

    public func convert() -> ChatChannelMember {
        .init(dto: self)
    }
}
