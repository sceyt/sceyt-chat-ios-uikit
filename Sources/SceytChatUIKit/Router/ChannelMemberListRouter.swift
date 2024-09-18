//
//  ChannelMemberListRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelMemberListRouter: Router<ChannelMemberListVC> {
    
    open func goChannelVC() {
        guard let viewController = channelVC else { return }
        rootVC.navigationController?.popToViewController(viewController, animated: true)
    }
    
    private var channelVC: ChannelVC? {
        rootVC.navigationController?.viewControllers.first(where: { $0 is ChannelVC }) as? ChannelVC
    }
    
    open func showAddMembers() {
        let viewController = ChannelAddMembersVC()
        let vm = rootVC.memberListViewModel!
        viewController.addMembersViewModel = ChannelAddMembersVM(channel: vm.channel,
                                                     title: vm.addTitle,
                                                     roleName: vm.addRole,
                                                     onlyDismissAfterDone: true)
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        rootVC.present(nav, animated: true)
    }
    
    open func showChannelInfoVC(channel: ChatChannel) {
        let viewController = Components.channelInfoVC.init()
        viewController.profileViewModel = Components.channelProfileVM.init(channel: channel)
        rootVC.show(viewController, sender: self)
    }
}
