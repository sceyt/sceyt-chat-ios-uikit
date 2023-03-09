//
//  SelectChannelMembersVM.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class SelectChannelMembersVM {
    
    @Published public var event: Event?
    public private(set) var users = [ChatUser]()
    public private(set) var query: UserListQuery!
    public private(set) var selectedUsers = [ChatUser]()
    private var isCreatedNewQuery = false
    
    private func userListQuery(_ query: String? = nil) -> UserListQuery {
        defer { isCreatedNewQuery = true }
        return UserListQuery
            .Builder()
            .limit(100)
            .query(query)
            .build()
    }
    
    open func makeQuery(_ query: String) {
        self.query = userListQuery(query)
    }
    
    func loadNextPage() {
        if query == nil {
            query = userListQuery()
        }
        guard query.hasNext, !query.loading else { return }
        query.loadNext { [weak self] (q, users, error) in
            guard let self,
                  let users
            else { return }
            let chatUsers = users.map{ ChatUser(user: $0) }
            if self.isCreatedNewQuery {
                self.users = chatUsers
                self.isCreatedNewQuery = false
            } else {
                self.users += chatUsers
            }
            self.event = .reload
        }
    }
    
    public var numberOfUser: Int {
        users.count
    }
    
    open func user(at indexPath: IndexPath) -> ChatUser? {
        guard indexPath.section == 0,
              users.indices.contains(indexPath.row)
        else { return nil }
        return users[indexPath.row]
    }
    
    @discardableResult
    open func select(at indexPath: IndexPath) -> Bool {
        guard let user = user(at: indexPath)
        else { return false }
        if selectedUsers.contains(user) {
            return true
        }
        selectedUsers.append(user)
        event = .select(user: user, isSelected: true)
        return true
    }
    
    @discardableResult
    open func deselect(at indexPath: IndexPath) -> Bool {
        guard let user = user(at: indexPath)
        else { return false }
        if let index = selectedUsers.firstIndex(of: user) {
            selectedUsers.remove(at: index)
            event = .select(user: user, isSelected: false)
            return true
        }
        return false
    }
    
    @discardableResult
    open func deselect(user: ChatUser) -> Bool {
        if let index = selectedUsers.firstIndex(of: user ) {
            selectedUsers.remove(at: index)
            event = .select(user: user, isSelected: false)
            return true
        }
        return false
    }
    
    open func isSelect(at indexPath: IndexPath) -> Bool {
        guard let user = user(at: indexPath)
        else { return false }
        return selectedUsers.contains(user)
    }
}


public extension SelectChannelMembersVM {
    
    enum Event {
        case reload
        case select(user: ChatUser, isSelected: Bool)
    }
    
}

