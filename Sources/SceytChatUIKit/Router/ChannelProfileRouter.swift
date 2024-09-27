//
//  ChannelProfileRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelProfileRouter: Router<ChannelInfoViewController> {
    open func showMuteOptionsAlert(
        selected: @escaping (SceytChatUIKit.Config.IntervalOption) -> Void,
        canceled: @escaping () -> Void
    ) {
        rootViewController.showBottomSheet(
            title: L10n.Channel.Info.Mute.title,
            actions: SceytChatUIKit.shared.config.muteChannelNotificationOptions.map { item in
                    .init(title: item.title, style: .default) { selected(item) }
            } + [.init(title: L10n.Alert.Button.cancel, style: .cancel) { canceled() }])
    }
    
    open func showAutoDeleteOptionsAlert(
        selected: @escaping (SceytChatUIKit.Config.IntervalOption) -> Void,
        canceled: @escaping () -> Void
    ) {
        rootViewController.showBottomSheet(
            title: L10n.Channel.Info.AutoDelete.title,
            actions: SceytChatUIKit.shared.config.messageAutoDeleteOptions.map { item in
                    .init(title: item.title, style: .default) { selected(item) }
            } + [.init(title: L10n.Alert.Button.cancel, style: .cancel) { canceled() }])
    }
    
    open func showAttachment(_ attachment: ChatMessage.Attachment) {
        let items = AttachmentModel.items(attachments: [attachment])
        guard !items.isEmpty else { return }
        let preview = FilePreviewController(
            items: items
                .map { .init(title: $0.name, url: $0.url) }
        )
        
        preview.present(on: rootViewController)
    }

    open func goChannelViewController() {
        guard let viewController = channelViewController else { return }
        rootViewController.navigationController?.popToViewController(viewController, animated: true)
    }
    
    open func goChannelListViewController() {
        guard let viewController = channelListViewController else { return }
        rootViewController.navigationController?.popToViewController(viewController, animated: true)
    }
    
    open func showMemberList() {
        let viewController = Components.channelMemberListViewController.init()
        viewController.memberListViewModel = Components.channelMemberListViewModel.init(channel: rootViewController.profileViewModel.channel)
        rootViewController.show(viewController, sender: self)
    }
    
    open func showAdminsList() {
        let viewController = Components.channelMemberListViewController.init()
        viewController.memberListViewModel = Components.channelMemberListViewModel.init(channel: rootViewController.profileViewModel.channel,
                                                                                        filterMembersByRole: SceytChatUIKit.shared.config.memberRolesConfig.admin)
        rootViewController.show(viewController, sender: self)
    }
    
    open func showEditChannel() {
        let viewController = Components.channelEditViewController.init()
        viewController.profileViewModel = Components.channelProfileEditViewModel.init(channel: rootViewController.profileViewModel.channel)
        rootViewController.show(viewController, sender: self)
    }

    public var channelListViewController: ChannelListViewController? {
        rootViewController.navigationController?.viewControllers.first(where: { $0 is ChannelListViewController }) as? ChannelListViewController
    }

    public var channelViewController: ChannelViewController? {
        rootViewController.navigationController?.viewControllers.first(where: { $0 is ChannelViewController }) as? ChannelViewController
    }
    
    open func goAvatar() {
        guard rootViewController.profileViewModel.channel.imageUrl != nil else { return }
        let viewController = Components.imagePreviewViewController.init()
        viewController.viewModel = Components.channelAvatarViewModel.init(channel: rootViewController.profileViewModel.channel)
        rootViewController.show(viewController, sender: self)
    }
    
    open func goMessageSearch() {
        channelViewController?.channelViewModel.startMessagesSearch()
        goChannelViewController()
    }
}
