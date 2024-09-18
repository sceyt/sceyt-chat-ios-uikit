//
//  CreateNewChannelViewModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import Foundation
import SceytChat

open class CreateNewChannelViewModel: NSObject {
    @Published public var event: Event?
    public private(set) var users = [ChatUser]()
    public private(set) var query: UserListQuery!
    public var isSearching = false

    override public required init() {
        super.init()
    }
    
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
        query.loadNext { [weak self] _, users, _ in
            guard let self,
                  let users
            else { return }
            let chatUsers = users.map { ChatUser(user: $0) }
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
    
    open func user(at indexPath: IndexPath) -> ChatUser? {
        guard indexPath.section == 0,
              users.indices.contains(indexPath.row)
        else { return nil }
        return users[indexPath.row]
    }
    
    open func createDirectChannel(userAt indexPath: IndexPath) {
        guard let user = user(at: indexPath)
        else { return }
        createDirectChannel(peer: user)
    }
    
    open func createDirectChannel(peer: ChatUser) {
        
        Components.channelCreator.init()
            .createLocalChannel(type: SceytChatUIKit.shared.config.directChannel,
                                members: [ChatChannelMember(user: peer, roleName: SceytChatUIKit.shared.config.chatRoleOwner),
                                          ChatChannelMember(id: me, roleName: SceytChatUIKit.shared.config.chatRoleOwner)])
        { [weak self] channel, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.event = .createChannelError(error)
                } else {
                    self?.event = .createdChannel(channel!)
                }
            }
        }
    }
    
    @objc
    open func search(query: String) {
        isSearching = true
        makeQuery(query)
        fetch(reload: true)
    }
    
    open func cancelSearch() {
        makeQuery("")
        fetch(reload: true)
        isSearching = false
    }
}

public extension CreateNewChannelViewModel {
    enum Event {
        case reload
        case createChannelError(Error)
        case createdChannel(ChatChannel)
    }
}

public struct ChannelMetadata: Codable {
    var d: String?
}
