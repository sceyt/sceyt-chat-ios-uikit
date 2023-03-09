//
//  UserDTO.swift
//  SceytChatUIKit
//
//

import Foundation
import CoreData
import SceytChat

@objc(UserDTO)
public class UserDTO: NSManagedObject {

    @NSManaged public var id: String
    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
    @NSManaged public var avatarUrl: URL?
    @NSManaged public var metadata: String?
    @NSManaged public var blocked: Bool
    @NSManaged public var activityState: Int16

    @NSManaged public var presenceState: Int16
    @NSManaged public var presenceStatus: String?
    @NSManaged public var presenceLastActiveAt: Date?

    @NSManaged public var message: Set<MessageDTO>?
    @NSManaged public var reaction: Set<ReactionDTO>?
    @NSManaged public var mention: Set<UserDTO>?
    @NSManaged public var member: Set<MemberDTO>?
    @NSManaged public var directChannel: Set<ChannelDTO>?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<UserDTO> {
        return NSFetchRequest<UserDTO>(entityName: entityName)
    }

    public static func fetch(id: UserId, context: NSManagedObjectContext) -> UserDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \UserDTO.id, ascending: false)
        request.predicate = .init(format: "id == %@", id)
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(id: UserId, context: NSManagedObjectContext) -> UserDTO {
        if let mo = fetch(id: id, context: context) {
            return mo
        }
        let mo = insertNewObject(into: context)
        mo.id = id
        return mo
    }

    public func map(_ map: User) -> UserDTO {
        id = map.id
        firstName = map.firstName
        lastName = map.lastName
        avatarUrl = map.avatarUrl
        metadata = map.metadata
        blocked = map.blocked
        activityState = Int16(map.activityState.rawValue)
        presenceState = Int16(map.presence.state.rawValue)
        presenceStatus = map.presence.status
        presenceLastActiveAt = map.presence.lastActiveAt
        return self
    }

    public func convert() -> ChatUser {
        .init(dto: self)
    }
}

extension UserDTO: Identifiable { }
