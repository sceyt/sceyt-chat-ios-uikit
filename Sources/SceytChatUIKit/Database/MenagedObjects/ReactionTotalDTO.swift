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
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \ReactionTotalDTO.key, ascending: false)
        request.predicate = .init(format: "message.id == %lld AND key = %@", messageId, key)
        return fetch(request: request, context: context).first
    }

    public static func fetchOrCreate(messageId: MessageId, key: String, context: NSManagedObjectContext) -> ReactionTotalDTO {
        if let r = fetch(messageId: messageId, key: key, context: context) {
            return r
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
