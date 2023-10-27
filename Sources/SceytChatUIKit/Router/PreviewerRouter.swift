//
//  PreviewerRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

open class PreviewerRouter: Router<PreviewerVC> {
    public enum ShareOption {
        case saveGallery
        case forward([ChannelId])
        case share
        case cancel
    }

    open func showShareActionSheet(
        previewItem: PreviewItem,
        from barButtonItem: UIBarButtonItem,
        callback: @escaping (ShareOption) -> Void
    ) {
        let isVideo = previewItem.attachment.type == "video"
        var actions = [SheetAction]()
        actions.append(
            .init(
                title: isVideo ? L10n.Previewer.saveVideo : L10n.Previewer.savePhoto,
                icon: .chatSavePhoto,
                style: .default
            ) {
                callback(.saveGallery)
            })

        actions.append(
            .init(
                title: L10n.Previewer.forward,
                icon: .chatForward,
                style: .default
            ) { [weak self] in
                self?.showForward { channels in
                    callback(.forward(channels.map { $0.id }))
                }
            })

        actions.append(
            .init(
                title: isVideo ? L10n.Previewer.shareVideo : L10n.Previewer.sharePhoto,
                icon: .chatShare,
                style: .default
            ) {
                callback(.share)
            })

        actions.append(
            .init(
                title: L10n.Alert.Button.cancel,
                style: .cancel
            ) {
                callback(.cancel)
            })
        
        rootVC.showBottomSheet(actions: actions)
    }
    
    open func showForward(_ handler: @escaping ([ChatChannel]) -> Void) {
        let vc = Components.channelForwardVC.init()
        vc.viewModel = Components.channelForwardVM.init(handler: handler)
        let nav = Components.navigationController.init()
        nav.viewControllers = [vc]
        rootVC.present(nav, animated: true)
    }
}
