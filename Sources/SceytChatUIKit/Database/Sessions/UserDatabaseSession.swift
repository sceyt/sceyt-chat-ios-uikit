//
//  UserDatabaseSession.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import CoreData
import SceytChat

public protocol UserDatabaseSession {

    @discardableResult
    func createOrUpdate(user: User) -> UserDTO

    @discardableResult
    func createOrUpdate(users: [User]) -> [UserDTO]
    
    @discardableResult
    func createOrUpdate(user: ChatUser) -> UserDTO
    
    @discardableResult
    func createOrUpdate(users: [ChatUser]) -> [UserDTO]
}

extension NSManagedObjectContext: UserDatabaseSession {

    @discardableResult
    public func createOrUpdate(user: User) -> UserDTO {
        UserDTO.fetchOrCreate(id: user.id, context: self).map(user)
    }

    @discardableResult
    public func createOrUpdate(users: [User]) -> [UserDTO] {
        users.map { createOrUpdate(user: $0) }
    }
    
    @discardableResult
    public func createOrUpdate(user: ChatUser) -> UserDTO {
        UserDTO.fetchOrCreate(id: user.id, context: self).map(user)
    }

    @discardableResult
    public func createOrUpdate(users: [ChatUser]) -> [UserDTO] {
        users.map { createOrUpdate(user: $0) }
    }
}

extension NSManagedObjectContext {
    
    internal func fetch(userIds: [UserId]) -> [UserDTO] {
        let request = UserDTO.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", userIds)
        return UserDTO.fetch(request: request, context: self)
    }
}
