//
//  BodyAttributeDTO.swift
//  SceytChatUIKit
//
//  Created by Duc on 17/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import CoreData
import Foundation
import SceytChat

@objc(BodyAttributeDTO)
public class BodyAttributeDTO: NSManagedObject {
    @NSManaged public var offset: Int
    @NSManaged public var length: Int
    @NSManaged public var type: String
    @NSManaged public var metadata: String?
    @NSManaged public var message: MessageDTO?

    @nonobjc
    public static func fetchRequest() -> NSFetchRequest<BodyAttributeDTO> {
        return NSFetchRequest<BodyAttributeDTO>(entityName: entityName)
    }
    
    @discardableResult
    public func map(_ map: Message.BodyAttribute) -> BodyAttributeDTO {
        offset = map.offset
        length = map.length
        type = map.type
        metadata = map.metadata
        return self
    }
    
    public func convert() -> ChatMessage.BodyAttribute {
        .init(dto: self)
    }
}
