//
//  CreateChannelRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class NewChannelRouter: Router<StartChatVC> {
    open func showChannel(_ channel: ChatChannel) {
        ChannelListRouter.showChannel(channel)
        rootVC.dismiss(animated: true)
    }

    func showCreatePrivateChannel() {
        let vc = SelectChannelMembersVC()
        vc.selectMemberViewModel = .init()
        rootVC.show(vc, sender: self)
    }

    func showCreatePublicChannel() {
        let vc = Components.createChannelVC.init()
        vc.viewModel = .init()
        rootVC.show(vc, sender: self)
    }
}

open class SelectChannelMembersRouter: Router<SelectChannelMembersVC> {
    open func showCreatePrivateChannel() {
        let vc = Components.createGroupVC.init()
        vc.viewModel = .init(users: rootVC.selectMemberViewModel.selectedUsers)
        rootVC.show(vc, sender: self)
    }
}

open class CreatePrivateChannelRouter: Router<CreateGroupVC> {
    open func showChannel(_ channel: ChatChannel) {
        ChannelListRouter.showChannel(channel)
        rootVC.dismiss(animated: true)
    }
}

open class CreatePublicChannelRouter: Router<CreateChannelVC> {
    func showAddMember(channel: ChatChannel) {
        let vc = ChannelAddMembersVC()
        vc.addMembersViewModel = ChannelAddMembersVM(channel: channel)
        rootVC.show(vc, sender: self)
    }
}
