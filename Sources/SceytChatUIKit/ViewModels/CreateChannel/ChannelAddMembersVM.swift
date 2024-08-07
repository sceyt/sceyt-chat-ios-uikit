//
//  ChannelAddMembersVM.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat
import Combine

open class ChannelAddMembersVM: SelectChannelMembersVM {
    
    @Published public var event1: Event?
    public let channel: ChatChannel
    public let title: String?
    public let roleName: String
    public let onlyDismissAfterDone: Bool
    
    required public init(channel: ChatChannel,
                         title: String? = nil,
                         roleName: String = SceytChatUIKit.shared.config.channelRoleSubscriber,
                         onlyDismissAfterDone: Bool = false) {
        self.channel = channel
        self.title = title
        self.roleName = roleName
        self.onlyDismissAfterDone = onlyDismissAfterDone
    }
    
    open func addMembers() {
        guard !selectedUsers.isEmpty
        else {
            event1 = .success
            return
        }
        let provider = Components.channelProvider.init(channelId: channel.id)
        let newMembers = selectedUsers.map {
            provider.setRole(name: roleName, userId: $0.id)
            return Member.Builder(id: $0.id)
                .roleName(roleName)
                .build()
        }
//        hud.isLoading = true

        provider
            .add(members: newMembers) { [weak self] error in
//                hud.isLoading = false
                if let error = error {
                    self?.event1 = .error(error)
                } else {
                    self?.event1 = .success
                }
            }

//        let newContacts = selectedUsers.filter { selected in !members.contains(where: { $0.id == selected.id }) }
//        if channel.type == .private, !newContacts.isEmpty {
//            SMS.sendMessage(
//                to: channel.id,
//                type: .addGroupMember,
//                metadata: try? SMS.Members(m: newContacts.map { $0.id }).asJSONString())
//        }
    }
}

public extension ChannelAddMembersVM {
    enum Event {
        case success
        case error(Error)
    }
}
