//
//  MarkerDTO.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 17.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

@objc(MarkerDTO)
public class MarkerDTO: NSManagedObject {
    
    @NSManaged public var messageId: Int64
    @NSManaged public var name: String
    @NSManaged public var createdAt: CDDate
    
    @NSManaged public var user: UserDTO?
    @NSManaged public var message: MessageDTO?
    
    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<MarkerDTO> {
        return NSFetchRequest<MarkerDTO>(entityName: entityName)
    }
    
    public static func fetch(
        messageId: MessageId,
        context: NSManagedObjectContext
    ) -> [MarkerDTO]? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MarkerDTO.name, ascending: false)
        request.predicate = .init(format: "messageId == %lld", messageId)
        return fetch(request: request, context: context)
    }
    
    public static func fetch(
        messageId: MessageId,
        name: String,
        context: NSManagedObjectContext
    ) -> MarkerDTO? {
        let request = fetchRequest()
        request.sortDescriptor = NSSortDescriptor(keyPath: \MarkerDTO.name, ascending: false)
        request.predicate = .init(format: "messageId == %lld AND name = %@", messageId, name)
        return fetch(request: request, context: context).first
    }
    
    public static func fetchOrCreate(messageId: MessageId, name: String, context: NSManagedObjectContext) -> MarkerDTO {
        if let r = fetch(messageId: messageId, name: name, context: context) {
            return r
        }
        
        let mo = insertNewObject(into: context)
        mo.messageId = Int64(messageId)
        mo.name = name
        return mo
    }
    
    public func map(_ map: Marker) -> MarkerDTO {
        name = map.name
        createdAt = map.createdAt.bridgeDate
        messageId = Int64(map.messageId)
        return self
    }
    
    public func convert() -> ChatMessage.Marker {
        .init(dto: self)
    }
}
