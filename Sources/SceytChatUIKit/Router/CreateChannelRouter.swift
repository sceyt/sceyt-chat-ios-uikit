//
//  CreateChannelRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class NewChannelRouter: Router<StartChatViewController> {
    open func showChannel(_ channel: ChatChannel) {
        ChannelListRouter.showChannel(channel)
        rootViewController.dismiss(animated: true)
    }

    func showCreatePrivateChannel() {
        let viewController = Components.selectUsersViewController.init()
        viewController.selectMemberViewModel = Components.selectChannelMembersViewModel.init()
        rootViewController.show(viewController, sender: self)
    }

    func showCreatePublicChannel() {
        let viewController = Components.createChannelViewController.init()
        viewController.viewModel = Components.createPublicChannelViewModel.init()
        rootViewController.show(viewController, sender: self)
    }
}

open class SelectChannelMembersRouter: Router<SelectUsersViewController> {
    open func showCreatePrivateChannel() {
        let viewController = Components.createGroupViewController.init()
        viewController.viewModel = Components.createPrivateChannelViewModel.init(users: rootViewController.selectMemberViewModel.selectedUsers)
        rootViewController.show(viewController, sender: self)
    }
}

open class CreatePrivateChannelRouter: Router<CreateGroupViewController> {
    open func showChannel(_ channel: ChatChannel) {
        ChannelListRouter.showChannel(channel)
        rootViewController.dismiss(animated: true)
    }
}

open class CreatePublicChannelRouter: Router<CreateChannelViewController> {
    func showAddMember(channel: ChatChannel) {
        let viewController = Components.addMembersViewController.init()
        viewController.addMembersViewModel = Components.channelAddMembersViewModel.init(channel: channel)
        rootViewController.show(viewController, sender: self)
    }
}
