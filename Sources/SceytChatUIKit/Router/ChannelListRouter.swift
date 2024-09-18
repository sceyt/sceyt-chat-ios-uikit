//
//  ChannelListRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

open class ChannelListRouter: Router<ChannelListViewController> {
    open func showChannelViewController(at indexPath: IndexPath) {
        guard let chatChannel = rootViewController.channelListViewModel.channel(at: indexPath)
        else { return }
        showChannelViewController(channel: chatChannel)
    }
    
    open func showChannelViewController(channelId: ChannelId) {
        if let chatChannel = rootViewController.channelListViewModel.channel(id: channelId) {
            showChannelViewController(channel: chatChannel)
        } else {
            rootViewController.channelListViewModel.fetchChannel(id: channelId) { [weak self] chatChannel in
                if let chatChannel {
                    self?.showChannelViewController(channel: chatChannel)
                }
            }
        }
    }
    
    open func showChannelViewController(channel: ChatChannel, animated: Bool = true) {
        if let opened = rootViewController.navigationController?.viewControllers.last(where: { $0 is ChannelViewController }) as? ChannelViewController,
           opened.channelViewModel.channel.id == channel.id
        {
            popTo(opened, animated: animated)
            return
        }
        let viewController = Components.channelViewController.init()
        viewController.hidesBottomBarWhenPushed = true
        viewController.channelViewModel = Components.channelVM
            .init(channel: channel)
        setViewControllers([rootViewController, viewController], animated: animated)
    }
    
    open class func findAndShowChannel(id: ChannelId) {
        if let mainViewController = UIApplication.shared.windows
            .compactMap({ $0.rootViewController as? UITabBarController })
            .first,
            let navViewController = mainViewController.viewControllers?.first as? UINavigationController,
            let channelListViewController = navViewController.viewControllers.first as? ChannelListViewController
        {
            channelListViewController.channelListRouter.showChannelViewController(channelId: id)
        }
    }
    
    open class func showChannel(_ channel: ChatChannel) {
        if let mainViewController = UIApplication.shared.windows
            .compactMap({ $0.rootViewController as? UITabBarController })
            .first,
            let navViewController = mainViewController.viewControllers?.first as? UINavigationController,
            let channelListViewController = navViewController.viewControllers.first as? ChannelListViewController
        {
            channelListViewController.channelListRouter.showChannelViewController(channel: channel)
        }
    }
    
    open func showNewChannel() {
        let viewController = Components.startChatViewController.init()
        viewController.viewModel = Components.createNewChannelVM.init()
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        rootViewController.present(nav, animated: true)
    }
    
    func showAskForDelete(completion: @escaping (Bool) -> Void) {
        rootViewController.showBottomSheet(title: L10n.Alert.Ask.delete, actions: [
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
        rootViewController.showBottomSheet(
            title: L10n.Channel.Profile.Mute.title,
            actions: SceytChatUIKit.shared.config.muteItems.map { item in
                    .init(title: item.title, style: .default) { selected(item) }
            } + [.init(title: L10n.Alert.Button.cancel, style: .cancel) { canceled() }])
    }
}
