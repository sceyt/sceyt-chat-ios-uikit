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
    @NSManaged public var channelId: Int64

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<MemberDTO> {
        return NSFetchRequest<MemberDTO>(entityName: entityName)
    }

    public static func fetch(id: UserId, channelId: ChannelId, context: NSManagedObjectContext) -> MemberDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MemberDTO.user?.id, ascending: false)
        request.predicate = .init(format: "user.id == %@ AND channelId == %lld", id, channelId)
        return fetch(request: request, context: context).first
    }
    
    public static func fetch(channelId: ChannelId, context: NSManagedObjectContext) -> [MemberDTO] {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MemberDTO.user?.id, ascending: false)
        request.predicate = .init(format: "channelId == %lld", channelId)
        return fetch(request: request, context: context)
    }

    public static func fetchOrCreate(id: UserId, channelId: ChannelId, context: NSManagedObjectContext) -> MemberDTO {
        if let mo = fetch(id: id, channelId: channelId, context: context) {
            return mo
        }

        let mo = insertNewObject(into: context)
        mo.channelId = Int64(channelId)
        mo.user?.id = id
        return mo
    }

    public func map(_ map: Member) -> MemberDTO {
        return self
    }

    public func convert() -> ChatChannelMember {
        .init(dto: self)
    }
}
