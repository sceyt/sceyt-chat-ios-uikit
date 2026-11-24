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
        username = map.username
        avatarUrl = map.avatarUrl
        
        updateMetadata(map.metadataMap)

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
        
        updateMetadata(map.metadataDict)

        blocked = map.blocked
        state = Int16(map.state.rawValue)
        presenceState = Int16(map.presence.state.presenceState.rawValue)
        presenceStatus = map.presence.status
        presenceLastActiveAt = map.presence.lastActiveAt
        return self
    }

    /// Brings the metadata rows in line with `metadata`, touching only what changed: a changed
    /// value is set on its row, a removed key's row is deleted, a new key gets a row. It used to
    /// delete every row and insert new ones on each save, so every save of an unchanged user
    /// (once per channel of a chat-list page) inserted and deleted rows and marked the user as
    /// changed. `nil` or empty removes all rows, as before.
    func updateMetadata(_ metadata: [String: String]?) {
        guard let context = managedObjectContext else { return }
        let metadata = metadata ?? [:]
        var rowsByKey = [String: UserMetadataDTO]()
        for row in metadataEntries ?? [] where !row.isDeleted {
            if rowsByKey[row.key] == nil, metadata[row.key] != nil {
                rowsByKey[row.key] = row
            } else {
                // A key no longer present, or a duplicate row for a key.
                context.delete(row)
            }
        }
        for (key, value) in metadata {
            if let row = rowsByKey[key] {
                if row.value != value {
                    row.value = value
                }
            } else {
                let row = UserMetadataDTO(context: context)
                row.key = key
                row.value = value
                row.user = self
            }
        }
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
        
        updateMetadata(map.metadataDict)
        
        return self
    }
}


extension UserDTO: Identifiable { }
