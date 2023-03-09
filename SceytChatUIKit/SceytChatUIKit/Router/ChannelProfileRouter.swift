//
//  ChannelProfileRouter.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileRouter: Router<ChannelProfileVC> {

    open func showPicker(sourceView: UIView, picked: @escaping (PickedData?) -> Void) {
//        openAttachmentPicker(
//            sources: [.media],
//            sourceView: sourceView,
//            callback: picked)
    }

    open func showMuteOptionsAlert(
        selected: @escaping (SCUIKitConfig.Mute) -> Void,
        canceled: @escaping () -> Void
    ) {

        let alert = UIAlertController(title: L10n.Channel.Profile.Mute.title,
                                      message: nil,
                                      preferredStyle: .actionSheet)
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = rootVC.view
            popoverPresentationController.sourceRect = .init(origin: rootVC.view.bounds.center, size: .zero)
        }
        Config.muteItems.forEach { mute in
            let action = UIAlertAction(title: mute.title, style: .default) { action in
                selected(mute)
            }
            alert.addAction(action)
        }

        let cancelAction = UIAlertAction(title: L10n.Alert.Button.cancel, style: .cancel) { _ in
            canceled()
        }
        alert.addAction(cancelAction)
        rootVC.present(alert, animated: true)
    }
    
    open func showChannelMoreAlert(
        titles: [String],
        selected: @escaping (String) -> Void,
        canceled: @escaping () -> Void
    ) {

        let alert = UIAlertController(title: nil,
                                      message: nil,
                                      preferredStyle: .actionSheet)
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = rootVC.view
            popoverPresentationController.sourceRect = .init(origin: rootVC.view.bounds.center, size: .zero)
        }
        titles.forEach { title in
            let action = UIAlertAction(title: title, style: .default) { action in
                selected(title)
            }
            alert.addAction(action)
        }

        let cancelAction = UIAlertAction(title: L10n.Alert.Button.cancel, style: .cancel) { _ in
            canceled()
        }
        alert.addAction(cancelAction)
        rootVC.present(alert, animated: true)
    }
    
    open func showAttachment(_ attachment: ChatMessage.Attachment) {
        let preview = FilePreviewController(
            items: AttachmentView.items(attachments: [attachment])
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
                                                                     filterMembersByRole: "admin")
        rootVC.show(vc, sender: self)
    }
    
    open func showEditChannel() {
        let vc = Components.channelProfileEditVC.init()
        vc.profileViewModel = .init(channel: rootVC.profileViewModel.channel)
        rootVC.show(vc, sender: self)
    }

    private var channelListVC: ChannelListVC? {
        rootVC.navigationController?.viewControllers.first(where: { $0 is ChannelListVC }) as? ChannelListVC
    }

    private var channelVC: ChannelVC? {
        rootVC.navigationController?.viewControllers.first(where: { $0 is ChannelVC }) as? ChannelVC
    }
}
