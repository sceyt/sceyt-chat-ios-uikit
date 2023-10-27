//
//  ReactionDTO.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

@objc(ReactionDTO)
public class ReactionDTO: NSManagedObject {

    @NSManaged public var id: Int64
    @NSManaged public var messageId: Int64
    @NSManaged public var key: String
    @NSManaged public var reason: String?
    @NSManaged public var createdAt: CDDate?
    @NSManaged public var score: Int32
    @NSManaged public var pending: Bool
    @NSManaged public var user: UserDTO?
    @NSManaged public var messageSelf: MessageDTO?
    @NSManaged public var message: MessageDTO?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<ReactionDTO> {
        return NSFetchRequest<ReactionDTO>(entityName: entityName)
    }

    public static func fetch(
        id: ReactionId,
        context: NSManagedObjectContext
    ) -> ReactionDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionDTO.key, ascending: false)
        request.predicate = .init(format: "id == %lld", id)
        return fetch(request: request, context: context).first
    }
    
    public static func fetch(
        userId: UserId,
        key: String,
        messageId: MessageId,
        context: NSManagedObjectContext
    ) -> ReactionDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionDTO.key, ascending: false)
        request.predicate = .init(format: "key = %@ AND user.id == %@ AND messageId == %lld", key, userId, messageId)
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(
        userId: UserId,
        key: String,
        messageId: MessageId,
        context: NSManagedObjectContext) -> ReactionDTO {
            if let r = fetch(userId: userId, key: key, messageId: messageId, context: context) {
                return r
            }
            
            let mo = insertNewObject(into: context)
            mo.key = key
            mo.messageId = Int64(messageId)
            return mo
        }

    public func map(_ map: Reaction) -> ReactionDTO {
        id = Int64(map.id)
        messageId = Int64(map.messageId)
        key = map.key
        reason = map.reason
        createdAt = map.createdAt.bridgeDate
        score = Int32(map.score)
        return self
    }

    public func convert() -> ChatMessage.Reaction {
        .init(dto: self)
    }
}

extension ReactionDTO: Identifiable { }

public extension ReactionDTO {
    
    static func lastReaction(predicate: NSPredicate, context: NSManagedObjectContext) -> ReactionDTO? {
        let key = "max"
        if let result = ReactionDTO.maxExpression(keyPaths: ["id"], predicate: predicate, context: context) as? [[String: Int64]],
           let dict = result.first,
           let id = dict[key] {
            let reaction = ReactionDTO.fetch(id: ReactionId(id), context: context)
            return reaction
        }
        return nil
    }
    
    static func unownedReactionIds(_ ids: [ReactionId], context: NSManagedObjectContext) -> [ReactionId] {
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ReactionDTO.entityName)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["id"]
        request.predicate = NSPredicate(format: "id IN %@ AND message == NULL", ids)
        if let results = ReactionDTO.fetch(request: request, context: context) as? [[String: Int64]] {
            return results.compactMap { $0.values.first.map { ReactionId($0) }}
        }
        return []
        
    }
}
