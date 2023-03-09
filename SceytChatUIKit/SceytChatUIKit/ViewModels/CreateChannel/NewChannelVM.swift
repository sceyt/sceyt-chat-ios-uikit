//
//  NewChannelVM.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class NewChannelVM {
    
    @Published public var event: Event?
    public private(set) var users = [ChatUser]()
    public private(set) var query: UserListQuery!
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
    
    open func createDirectChannel(userAt indexPath: IndexPath) {
        guard let user = user(at: indexPath)
        else { return }
        
        ChannelCreator()
            .createDirectChannel(peer: user.id) { [weak self] channel, error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.event = .createChannelError(error)
                    } else {
                        self?.event = .createdChannel(channel!)
                    }
                }
            }
    }
}

public extension NewChannelVM {
    
    enum Event {
        case reload
        case createChannelError(Error)
        case createdChannel(ChatChannel)
    }

}

public struct ChannelMetadata: Codable {
    var d: String?
}
