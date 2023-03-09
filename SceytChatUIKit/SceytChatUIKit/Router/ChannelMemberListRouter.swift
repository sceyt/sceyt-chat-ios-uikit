//
//  ChannelMemberListRouter.swift
//  SceytChatUIKit
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
}
