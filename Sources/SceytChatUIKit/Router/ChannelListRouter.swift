//
//  ChannelListRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

open class ChannelListRouter: Router<ChannelListVC> {
    open func showChannelVC(at indexPath: IndexPath) {
        guard let chatChannel = rootVC.channelListViewModel.channel(at: indexPath)
        else { return }
        showChannelVC(channel: chatChannel)
    }
    
    open func showChannelVC(channelId: ChannelId) {
        if let chatChannel = rootVC.channelListViewModel.channel(id: channelId) {
            showChannelVC(channel: chatChannel)
        } else {
            rootVC.channelListViewModel.fetchChannel(id: channelId) { [weak self] chatChannel in
                if let chatChannel {
                    self?.showChannelVC(channel: chatChannel)
                }
            }
        }
    }
    
    open func showChannelVC(channel: ChatChannel, animated: Bool = true) {
        if let opened = rootVC.navigationController?.viewControllers.last(where: { $0 is ChannelVC }) as? ChannelVC,
           opened.channelViewModel.channel.id == channel.id
        {
            popTo(opened, animated: animated)
            return
        }
        let vc = Components.channelVC.init()
        vc.hidesBottomBarWhenPushed = true
        vc.channelViewModel = Components.channelVM
            .init(channel: channel)
        setViewControllers([rootVC, vc], animated: animated)
    }
    
    open class func findAndShowChannel(id: ChannelId) {
        if let mainVC = UIApplication.shared.windows
            .compactMap({ $0.rootViewController as? UITabBarController })
            .first,
            let navVC = mainVC.viewControllers?.first as? UINavigationController,
            let channelListVC = navVC.viewControllers.first as? ChannelListVC
        {
            channelListVC.channelListRouter.showChannelVC(channelId: id)
        }
    }
    
    open class func showChannel(_ channel: ChatChannel) {
        if let mainVC = UIApplication.shared.windows
            .compactMap({ $0.rootViewController as? UITabBarController })
            .first,
            let navVC = mainVC.viewControllers?.first as? UINavigationController,
            let channelListVC = navVC.viewControllers.first as? ChannelListVC
        {
            channelListVC.channelListRouter.showChannelVC(channel: channel)
        }
    }
    
    open func showNewChannel() {
        let vc = Components.createNewChannelVC.init()
        vc.viewModel = Components.createNewChannelVM.init()
        let nav = Components.navigationController.init()
        nav.viewControllers = [vc]
        rootVC.present(nav, animated: true)
    }
    
    func showAskForDelete(completion: @escaping (Bool) -> Void) {
        rootVC.showBottomSheet(title: L10n.Alert.Ask.delete, actions: [
            .init(title: L10n.Alert.Button.delete, style: .destructive) {
                completion(true)
            },
            .init(title: L10n.Alert.Button.cancel, style: .cancel) {
                completion(false)
            }
        ])
    }
    
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
}
