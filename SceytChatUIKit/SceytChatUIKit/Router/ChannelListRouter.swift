//
//  ChannelListRouter.swift
//  SceytChatUIKit
//

import UIKit
import SceytChat

open class ChannelListRouter: Router<ChannelListVC> {

    open func showChannelVC(at indexPath: IndexPath) {
        guard let chatChannel = rootVC.channelListViewModel.channel(at: indexPath)
        else { return }
        showChannelVC(channel: chatChannel)
    }
    
    open func showChannelVC(channelId: ChannelId) {
        guard let chatChannel = rootVC.channelListViewModel.channel(id: channelId)
        else { return }
       showChannelVC(channel: chatChannel)
    }
    
    open func showChannelVC(channel: ChatChannel) {
        if let opened = rootVC.navigationController?.viewControllers.last as? ChannelVC,
           opened.channelViewModel.channel.id == channel.id {
            return
        }
        let vc = Components.channelVC.init()
        vc.channelViewModel = Components.channelVM
            .init(channel: channel)
        vc.hidesBottomBarWhenPushed = true
        _ = vc.view //load
        rootVC.show(vc, sender: self)
    }
    
    open class func findAndShowChannel(id: ChannelId) {
        if let mainVC = UIApplication.shared.windows
            .compactMap({ $0.rootViewController as? UITabBarController })
            .first,
           let navVC = mainVC.viewControllers?.first as? UINavigationController,
           let channelListVC = navVC.viewControllers.first as? ChannelListVC {
            channelListVC.channelListRouter.popToRoot(animated: false)
            channelListVC.channelListRouter.showChannelVC(channelId: id)
        }
    }
    
    open func showNewChannel() {
        let vc = NewChannelVC()
        vc.viewModel = .init()
        let nav = UINavigationController(rootViewController: vc)
        rootVC.present(nav, animated: true)
    }
}
