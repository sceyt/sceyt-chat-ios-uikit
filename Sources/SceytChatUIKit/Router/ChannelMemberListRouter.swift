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
        let viewController = Components.addMembersViewController.init()
        let viewModel = rootViewController.memberListViewModel!
        viewController.addMembersViewModel = ChannelAddMembersViewModel(channel: viewModel.channel,
                                                     title: viewModel.addTitle,
                                                     roleName: viewModel.addRole,
                                                     onlyDismissAfterDone: true)
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        rootViewController.present(nav, animated: true)
    }
    
    open func showChannelInfoViewController(channel: ChatChannel) {
        let viewController = Components.channelInfoViewController.init()
        viewController.profileViewModel = Components.channelProfileViewModel.init(channel: channel,
                                                                                  appearance: MessageCell.appearance)
        rootViewController.show(viewController, sender: self)
    }
}
