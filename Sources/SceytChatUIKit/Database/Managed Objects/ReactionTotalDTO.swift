//
//  ReactionTotalDTO.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 17.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

import CoreData
import SceytChat

@objc(ReactionTotalDTO)
public class ReactionTotalDTO: NSManagedObject {
    
    @NSManaged public var key: String
    @NSManaged public var score: Int64
    @NSManaged public var count: Int64
    
    @NSManaged public var message: MessageDTO?
    
    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<ReactionTotalDTO> {
        return NSFetchRequest<ReactionTotalDTO>(entityName: entityName)
    }
    
    public static func fetch(
        messageId: MessageId,
        context: NSManagedObjectContext
    ) -> [ReactionTotalDTO]? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionTotalDTO.key, ascending: false)
        request.predicate = .init(format: "message.id == %lld", messageId)
        return fetch(request: request, context: context)
    }
    
    public static func fetch(
        messageId: MessageId,
        key: String,
        context: NSManagedObjectContext
    ) -> ReactionTotalDTO? {
        fetchAll(messageId: messageId, key: key, context: context).first
    }

    public static func fetchAll(
        messageId: MessageId,
        key: String,
        context: NSManagedObjectContext
    ) -> [ReactionTotalDTO] {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionTotalDTO.key, ascending: false)
        request.predicate = .init(format: "message.id == %lld AND key = %@", messageId, key)
        return fetch(request: request, context: context)
    }

    /// There is no store-level uniqueness constraint on (message, key) — the logical key
    /// spans a relationship, and retrofitting a constraint would fail lightweight migration
    /// on any store that already contains duplicates. Writers without shared visibility
    /// (a notification-service extension persisting a push while the main app persists the
    /// socket event) can therefore both insert the same total. Heal here instead: every
    /// write that touches a (message, key) collapses its duplicates, keeping the row with
    /// the highest count.
    public static func fetchOrCreate(messageId: MessageId, key: String, context: NSManagedObjectContext) -> ReactionTotalDTO {
        let existing = fetchAll(messageId: messageId, key: key, context: context)
        if let keeper = existing.max(by: { $0.count < $1.count }) {
            existing.forEach {
                if $0 !== keeper {
                    context.delete($0)
                }
            }
            return keeper
        }

        let mo = insertNewObject(into: context)
        mo.key = key
        return mo
    }
    
    public func map(_ map: ReactionTotal) -> ReactionTotalDTO {
        key = map.key
        score = Int64(map.score)
        count = Int64(map.count)
        return self
    }
    
    public func convert() -> ChatMessage.ReactionTotal {
        .init(dto: self)
    }
}
