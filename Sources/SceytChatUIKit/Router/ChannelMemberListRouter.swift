//
//  ChannelMemberListRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelMemberListRouter: Router<ChannelMemberListViewController> {
    
    open func goChannelViewController() {
        guard let viewController = channelViewController else { return }
        rootViewController.navigationController?.popToViewController(viewController, animated: true)
    }
    
    private var channelViewController: ChannelViewController? {
        rootViewController.navigationController?.viewControllers.first(where: { $0 is ChannelViewController }) as? ChannelViewController
    }
    
    open func showAddMembers() {
        let viewController = ChannelAddMembersViewController()
        let vm = rootViewController.memberListViewModel!
        viewController.addMembersViewModel = ChannelAddMembersVM(channel: vm.channel,
                                                     title: vm.addTitle,
                                                     roleName: vm.addRole,
                                                     onlyDismissAfterDone: true)
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        rootViewController.present(nav, animated: true)
    }
    
    open func showChannelInfoViewController(channel: ChatChannel) {
        let viewController = Components.channelInfoViewController.init()
        viewController.profileViewModel = Components.channelProfileVM.init(channel: channel)
        rootViewController.show(viewController, sender: self)
    }
}
