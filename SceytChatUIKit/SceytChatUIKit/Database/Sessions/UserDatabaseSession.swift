//
//  UserDatabaseSession.swift
//  SceytChatUIKit
//

import Foundation
import CoreData
import SceytChat

public protocol UserDatabaseSession {

    @discardableResult
    func createOrUpdate(user: User) -> UserDTO

    @discardableResult
    func createOrUpdate(users: [User]) -> [UserDTO]
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

}
