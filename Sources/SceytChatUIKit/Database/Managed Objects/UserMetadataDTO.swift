//
//  UserMetadataDTO.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 07.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData

@objc(UserMetadataDTO)
public class UserMetadataDTO: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
    @NSManaged public var user: UserDTO?
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserMetadataDTO> {
        return NSFetchRequest<UserMetadataDTO>(entityName: entityName)
    }
}

extension UserMetadataDTO : Identifiable { }
