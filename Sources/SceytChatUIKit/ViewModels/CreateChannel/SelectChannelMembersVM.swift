//
//  SelectChannelMembersVM.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

open class SelectChannelMembersVM: NSObject {
    
    @Published public var event: Event?
    public private(set) var users = [ChatUser]()
    public private(set) var query: UserListQuery!
    public private(set) var selectedUsers = [ChatUser]()

    private func userListQuery(_ query: String? = nil) -> UserListQuery {
        return UserListQuery
            .Builder()
            .limit(100)
            .query(query)
            .build()
    }
    
    open func makeQuery(_ query: String) {
        self.query = userListQuery(query)
    }
    
    func fetch(reload: Bool) {
        var reload = reload
        if query == nil {
            query = userListQuery()
            reload = true
        }
        guard query.hasNext, !query.loading else { return }
        query.loadNext { [weak self] (q, users, error) in
            guard let self,
                  let users
            else { return }
            let chatUsers = users.map{ ChatUser(user: $0) }
            if reload {
                self.users = chatUsers
            } else {
                self.users += chatUsers
            }
            self.event = .reload
        }
    }
    
    public var numberOfUser: Int {
        users.count
    }
    
    open func indexPath(user: ChatUser) -> IndexPath? {
        if let row = users.firstIndex(of: user) {
            return .init(row: row, section: 0)
        }
        return nil
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
    
    @objc
    open func search(query: String) {
        makeQuery(query)
        fetch(reload: true)
    }
    
    open func cancelSearch() {
        makeQuery("")
        fetch(reload: true)
    }
}


public extension SelectChannelMembersVM {
    
    enum Event {
        case reload
        case select(user: ChatUser, isSelected: Bool)
    }
    
}

