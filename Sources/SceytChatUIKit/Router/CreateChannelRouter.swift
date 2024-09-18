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
        let viewController = SelectChannelMembersVC()
        viewController.selectMemberViewModel = .init()
        rootVC.show(viewController, sender: self)
    }

    func showCreatePublicChannel() {
        let viewController = Components.createChannelVC.init()
        viewController.viewModel = .init()
        rootVC.show(viewController, sender: self)
    }
}

open class SelectChannelMembersRouter: Router<SelectChannelMembersVC> {
    open func showCreatePrivateChannel() {
        let viewController = Components.createGroupVC.init()
        viewController.viewModel = .init(users: rootVC.selectMemberViewModel.selectedUsers)
        rootVC.show(viewController, sender: self)
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
        let viewController = ChannelAddMembersVC()
        viewController.addMembersViewModel = ChannelAddMembersVM(channel: channel)
        rootVC.show(viewController, sender: self)
    }
}
