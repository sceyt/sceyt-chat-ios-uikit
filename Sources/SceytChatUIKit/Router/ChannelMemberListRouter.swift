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
        guard let vc = channelVC else { return }
        rootVC.navigationController?.popToViewController(vc, animated: true)
    }
    
    private var channelVC: ChannelVC? {
        rootVC.navigationController?.viewControllers.first(where: { $0 is ChannelVC }) as? ChannelVC
    }
    
    open func showAddMembers() {
        let vc = ChannelAddMembersVC()
        let vm = rootVC.memberListViewModel!
        vc.addMembersViewModel = ChannelAddMembersVM(channel: vm.channel,
                                                     title: vm.addTitle,
                                                     roleName: vm.addRole,
                                                     onlyDismissAfterDone: true)
        let nav = Components.navigationController.init()
        nav.viewControllers = [vc]
        rootVC.present(nav, animated: true)
    }
    
    open func showChannelProfileVC(channel: ChatChannel) {
        let vc = Components.channelProfileVC.init()
        vc.profileViewModel = Components.channelProfileVM.init(channel: channel)
        rootVC.show(vc, sender: self)
    }
}
