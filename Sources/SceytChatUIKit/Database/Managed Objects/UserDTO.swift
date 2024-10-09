//
//  UserDTO.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

@objc(UserDTO)
public class UserDTO: NSManagedObject {

    @NSManaged public var id: String
    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
    @NSManaged public var username: String?
    @NSManaged public var avatarUrl: String?
    @NSManaged public var metadataEntries: Set<UserMetadataDTO>?
    @NSManaged public var blocked: Bool
    @NSManaged public var state: Int16

    @NSManaged public var presenceState: Int16
    @NSManaged public var presenceStatus: String?
    @NSManaged public var presenceLastActiveAt: Date?

    @NSManaged public var message: Set<MessageDTO>?
    @NSManaged public var reaction: Set<ReactionDTO>?
    @NSManaged public var mention: Set<UserDTO>?
    @NSManaged public var member: Set<MemberDTO>?

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
    
    public static func fetch(ids: [UserId], context: NSManagedObjectContext) -> [UserDTO] {
        guard !ids.isEmpty
        else { return [] }
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \UserDTO.id, ascending: false)
        request.predicate = .init(format: "id in %@", ids)
        return fetch(request: request, context: context)
    }

    public static func fetchOrCreate(id: UserId, context: NSManagedObjectContext) -> UserDTO {
        if let mo = fetch(id: id, context: context) {
            return mo
        }
        logger.debug("[ChatChannel] observer, create \(id)")
        let mo = insertNewObject(into: context)
        mo.id = id
        return mo
    }

    public func map(_ map: User) -> UserDTO {
        id = map.id
        firstName = map.firstName
        lastName = map.lastName
        avatarUrl = map.avatarUrl
        blocked = map.blocked
        state = Int16(map.state.rawValue)
        presenceState = Int16(map.presence.state.rawValue)
        presenceStatus = map.presence.status
        presenceLastActiveAt = map.presence.lastActiveAt
        return self
    }
    
    public func map(_ map: ChatUser) -> UserDTO {
        id = map.id
        firstName = map.firstName
        lastName = map.lastName
        username = map.username
        avatarUrl = map.avatarUrl
        
        // Remove existing metadata entries
        if let existingEntries = metadataEntries {
            for entry in existingEntries {
                managedObjectContext?.delete(entry)
            }
        }
        
        if let metadataDict = map.metadataDict {
            var newEntries = Set<UserMetadataDTO>()
            for (key, value) in metadataDict {
                let entry = UserMetadataDTO(context: managedObjectContext!)
                entry.key = key
                entry.value = value
                entry.user = self
                newEntries.insert(entry)
            }
            metadataEntries = newEntries
        }

        blocked = map.blocked
        state = Int16(map.state.rawValue)
        presenceState = Int16(map.presence.state.presenceState.rawValue)
        presenceStatus = map.presence.status
        presenceLastActiveAt = map.presence.lastActiveAt
        return self
    }

    public func convert() -> ChatUser {
        .init(dto: self)
    }
}

extension UserDTO {
    
    func map(_ map: NotificationPayload.User) -> UserDTO {
        id = map.id
        firstName = map.firstName
        lastName = map.lastName
        username = map.username
        
        // Remove existing metadata entries
        if let existingEntries = metadataEntries {
            for entry in existingEntries {
                managedObjectContext?.delete(entry)
            }
        }
        
        var newEntries = Set<UserMetadataDTO>()
        for (key, value) in map.metadataDict {
            let entry = UserMetadataDTO(context: managedObjectContext!)
            entry.key = key
            entry.value = value
            entry.user = self
            newEntries.insert(entry)
        }
        metadataEntries = newEntries
        
        return self
    }
}


extension UserDTO: Identifiable { }
