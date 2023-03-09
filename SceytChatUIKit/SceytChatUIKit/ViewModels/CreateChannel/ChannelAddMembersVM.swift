//
//  ChannelAddMembersVM.swift
//  SceytChatUIKit
//

import Foundation
import SceytChat

open class ChannelAddMembersVM: SelectChannelMembersVM {
    
    @Published public var event1: Event?
    public let channel: ChatChannel
    public let roleName: String
    
    required public init(channel: ChatChannel,
                         roleName: String = SCUIKitConfig.channelRoleSubscriber) {
        self.channel = channel
        self.roleName = roleName
    }
    
    open func addMembers() {
        guard !selectedUsers.isEmpty
        else {
            event1 = .success
            return
        }
        let provider = ChannelProvider(channelId: channel.id)
        let newMembers = selectedUsers.map {
            provider.setRole(name: roleName, userId: $0.id)
            return Member.Builder(id: $0.id)
                .roleName(roleName)
                .build()
        }
//        HUD.isLoading = true

        provider
            .add(members: newMembers) { [weak self] error in
//                HUD.isLoading = false
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
