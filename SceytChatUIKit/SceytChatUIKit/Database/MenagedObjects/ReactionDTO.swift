//
//  ReactionDTO.swift
//  SceytChatUIKit
//
//

import Foundation
import CoreData
import SceytChat

@objc(ReactionDTO)
public class ReactionDTO: NSManagedObject {

    @NSManaged public var key: String
    @NSManaged public var reason: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var score: Int32
    @NSManaged public var user: UserDTO?
    @NSManaged public var messageSelf: MessageDTO?
    @NSManaged public var messageLast: MessageDTO?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<ReactionDTO> {
        return NSFetchRequest<ReactionDTO>(entityName: entityName)
    }

    public static func create(context: NSManagedObjectContext) -> ReactionDTO {
        insertNewObject(into: context)
    }

    public func map(_ map: Reaction) -> ReactionDTO {
        key = map.key
        reason = map.reason
        updatedAt = map.updatedAt
        score = Int32(map.score)
        return self
    }
}

extension ReactionDTO: Identifiable { }
