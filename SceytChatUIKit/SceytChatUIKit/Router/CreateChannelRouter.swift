//
//  CreateChannelRouter.swift
//  SceytChatUIKit
//

import UIKit


open class NewChannelRouter: Router<NewChannelVC> {

    open func showChannel(_ channel: ChatChannel) {
        rootVC.dismiss(animated: false)
        ChannelListRouter.findAndShowChannel(id: channel.id)
    }
   
    func showCreatePrivateChannel() {
        let vc = SelectChannelMembersVC()
        vc.selectMemberViewModel = .init()
        rootVC.show(vc, sender: self)
    }
    
    func showCreatePublicChannel() {
        let vc = CreatePublicChannelVC()
        vc.viewModel = .init()
        rootVC.show(vc, sender: self)
    }
}

open class SelectChannelMembersRouter: Router<SelectChannelMembersVC> {
    
    open func showCreatePrivateChannel() {
        let vc = CreatePrivateChannelVC()
        vc.viewModel = .init(users: rootVC.selectMemberViewModel.selectedUsers)
        rootVC.show(vc, sender: self)
    }
}

open class CreatePrivateChannelRouter: Router<CreatePrivateChannelVC> {
    
    
    
}

open class CreatePublicChannelRouter: Router<CreatePublicChannelVC> {
    
    func showAddMember(channel: ChatChannel) {
        let vc = ChannelAddMembersVC()
        vc.addMembersViewModel = ChannelAddMembersVM(channel: channel)
        rootVC.show(vc, sender: self)
    }
    
}


