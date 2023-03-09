//
//  MemberDTO+CoreDataClass.swift
//  
//
//
//

import Foundation
import CoreData
import SceytChat

@objc(MemberDTO)
public class MemberDTO: NSManagedObject {

    @NSManaged public var role: RoleDTO?
    @NSManaged public var user: UserDTO?
    @NSManaged public var channels: Set<ChannelDTO>?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<MemberDTO> {
        return NSFetchRequest<MemberDTO>(entityName: entityName)
    }

    public static func fetch(id: UserId, context: NSManagedObjectContext) -> MemberDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MemberDTO.user?.id, ascending: false)
        request.predicate = .init(format: "user.id == %@", id)
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(id: UserId, context: NSManagedObjectContext) -> MemberDTO {
        if let mo = fetch(id: id, context: context) {
            return mo
        }

        let mo = insertNewObject(into: context)
        return mo
    }

    public func map(_ map: Member) -> MemberDTO {
        return self
    }

    public func convert() -> ChatChannelMember {
        .init(dto: self)
    }
}
