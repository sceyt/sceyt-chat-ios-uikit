//
//  ChannelProfileRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileRouter: Router<ChannelProfileVC> {
    open func showMuteOptionsAlert(
        selected: @escaping (SceytChatUIKit.Config.OptionItem) -> Void,
        canceled: @escaping () -> Void
    ) {
        rootVC.showBottomSheet(
            title: L10n.Channel.Profile.Mute.title,
            actions: SceytChatUIKit.shared.config.muteItems.map { item in
                    .init(title: item.title, style: .default) { selected(item) }
            } + [.init(title: L10n.Alert.Button.cancel, style: .cancel) { canceled() }])
    }
    
    open func showAutoDeleteOptionsAlert(
        selected: @escaping (SceytChatUIKit.Config.OptionItem) -> Void,
        canceled: @escaping () -> Void
    ) {
        rootVC.showBottomSheet(
            title: L10n.Channel.Profile.AutoDelete.title,
            actions: SceytChatUIKit.shared.config.autoDeleteItems.map { item in
                    .init(title: item.title, style: .default) { selected(item) }
            } + [.init(title: L10n.Alert.Button.cancel, style: .cancel) { canceled() }])
    }
    
    open func showAttachment(_ attachment: ChatMessage.Attachment) {
        let items = AttachmentView.items(attachments: [attachment])
        guard !items.isEmpty else { return }
        let preview = FilePreviewController(
            items: items
                .map { .init(title: $0.name, url: $0.url) }
        )
        
        preview.present(on: rootVC)
    }

    open func goChannelVC() {
        guard let vc = channelVC else { return }
        rootVC.navigationController?.popToViewController(vc, animated: true)
    }
    
    open func goChannelListVC() {
        guard let vc = channelListVC else { return }
        rootVC.navigationController?.popToViewController(vc, animated: true)
    }
    
    open func showMemberList() {
        let vc = Components.channelMemberListVC.init()
        vc.memberListViewModel = Components.channelMemberListVM.init(channel: rootVC.profileViewModel.channel)
        rootVC.show(vc, sender: self)
    }
    
    open func showAdminsList() {
        let vc = Components.channelMemberListVC.init()
        vc.memberListViewModel = Components.channelMemberListVM.init(channel: rootVC.profileViewModel.channel,
                                                                     filterMembersByRole: SceytChatUIKit.shared.config.chatRoleAdmin)
        rootVC.show(vc, sender: self)
    }
    
    open func showEditChannel() {
        let vc = Components.channelProfileEditVC.init()
        vc.profileViewModel = Components.channelProfileEditVM.init(channel: rootVC.profileViewModel.channel)
        rootVC.show(vc, sender: self)
    }

    public var channelListVC: ChannelListVC? {
        rootVC.navigationController?.viewControllers.first(where: { $0 is ChannelListVC }) as? ChannelListVC
    }

    public var channelVC: ChannelVC? {
        rootVC.navigationController?.viewControllers.first(where: { $0 is ChannelVC }) as? ChannelVC
    }
    
    open func goAvatar() {
        guard rootVC.profileViewModel.channel.imageUrl != nil else { return }
        let vc = Components.channelAvatarVC.init()
        vc.viewModel = Components.channelAvatarVM.init(channel: rootVC.profileViewModel.channel)
        rootVC.show(vc, sender: self)
    }
    
    open func goMessageSearch() {
        channelVC?.channelViewModel.startMessagesSearch()
        goChannelVC()
    }
}
