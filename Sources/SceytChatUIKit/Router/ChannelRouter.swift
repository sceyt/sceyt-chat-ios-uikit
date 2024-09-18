//
//  ChannelRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import AVKit
import UIKit
import SceytChat

open class ChannelRouter: Router<ChannelVC> {
    open func showThreadForMessage(_ message: ChatMessage) {
        let chatVC = Components.channelVC.init()
        chatVC.channelViewModel = Components.channelVM
            .init(
                channel: rootVC.channelViewModel.channel,
                threadMessage: message
            )
        chatVC.hidesBottomBarWhenPushed = true
        rootVC.show(chatVC, sender: self)
    }

    open func showChannelProfile() {
        let profileVC = Components.channelInfoVC.init()
        profileVC.profileViewModel = Components.channelProfileVM
            .init(
                channel: rootVC.channelViewModel.channel
            )
        rootVC.show(profileVC, sender: self)
    }

    open func showAttachment(_ attachment: ChatMessage.Attachment) {
        
        let items = AttachmentView.items(attachments: [attachment])
        guard !items.isEmpty else { return }
        let preview = FilePreviewController(
            items: items
                .map { .init(title: $0.name, url: $0.url) }
        )
        
        let isFirstResponder = rootVC.inputTextView.isFirstResponder
        rootVC.inputTextView.resignFirstResponder()
        preview.present(on: rootVC) {
            if isFirstResponder, case .didDismiss = $0 {
                self.rootVC.inputTextView.becomeFirstResponder()
            }
        }
    }

    open func showConfirmationAlertForDeleteMessage(
        _ confirmed: @escaping (Bool) -> Void
    ) {
        rootVC.showAlert(
            title: L10n.Message.Alert.Delete.title,
            message: L10n.Message.Alert.Delete.description,
            actions: [
                .init(title: L10n.Alert.Button.cancel, style: .cancel) {
                    confirmed(false)
                },
                .init(title: L10n.Alert.Button.delete, style: .destructive) {
                    confirmed(true)
                }])
    }

    open func showEmojis() -> EmojiPickerVC {
        let emojiPickerVC = Components.emojiPickerVC.init()
        emojiPickerVC.viewModel = Components.emojiListVM.init()
        let nav = EmojiViewInteractiveTransitionNavigationController
            .init(rootViewController: emojiPickerVC)
        rootVC.present(nav, animated: true)
        return emojiPickerVC
    }

    open func playFrom(url: URL) {
        let player = AVPlayer(url: url)
        let viewController = AVPlayerViewController()
        viewController.player = player

        rootVC.present(viewController, animated: true) {
            viewController.player?.play()
        }
    }

    @discardableResult
    open func showReactions(
        message: ChatMessage
    ) -> ReactionsInfoVC {
        let reactionPageVC = Components.reactionsInfoVC.init()
        let reactionScores = message.reactionScores?.sorted(by: { $0.key > $1.key && $0.value > $1.value }) ?? []
        let reactionScoreViewModel = ReactionScoreViewModel(reactionScores: reactionScores)
        var userReactionViewModels: [UserReactionViewModel] = .init()
        userReactionViewModels.reserveCapacity(reactionScores.count + 1)
        userReactionViewModels.append(.init(messageId: message.id, reactionKey: nil))
        reactionScores.forEach { key, _ in
            userReactionViewModels.append(.init(messageId: message.id, reactionKey: key))
        }
        reactionPageVC.reactionScoreViewModel = reactionScoreViewModel
        reactionPageVC.userReactionsViewModel = userReactionViewModels
        reactionPageVC.modalPresentationStyle = .custom
        rootVC.present(reactionPageVC, animated: true)
        return reactionPageVC
    }
    
    open func showChannelInfoVC(channel: ChatChannel) {
        let viewController = Components.channelInfoVC.init()
        viewController.hidesBottomBarWhenPushed = true
        viewController.profileViewModel = Components.channelProfileVM.init(channel: channel)
        self.rootVC.show(viewController, sender: self)
    }
    
    open func showDeleteOptions(clear: Bool) {
        var actions = [SheetAction]()
        actions.append(.init(title: L10n.Message.Action.Subtitle.deleteAll,
                             icon: .chatDelete,
                             style: .destructive,
                             handler: { [weak self] in
            guard let self else { return }
            if clear {
                self.rootVC.channelViewModel.deleteAllMessages(forMeOnly: false) { [weak self] error in
                    guard let self else { return }
                    if let error {
                        self.showAlert(error: error)
                    }
                }
            } else {
                self.rootVC.channelViewModel.deleteSelectedMessages(type: SceytChatUIKit.shared.config.shouldHardDeleteMessageForAll ? .deleteHard : .deleteForEveryone)
            }
            
            self.rootVC.channelViewModel.isEditing = false
        }))
        actions.append(.init(title: L10n.Message.Action.Subtitle.deleteMe,
                             icon: .chatDelete,
                             style: .destructive,
                             handler: { [weak self] in
            guard let self else { return }
            if clear {
                self.rootVC.channelViewModel.deleteAllMessages(forMeOnly: true) { [weak self] error in
                    guard let self else { return }
                    if let error {
                        self.showAlert(error: error)
                    }
                }
            } else {
                self.rootVC.channelViewModel.deleteSelectedMessages(type: .deleteForMe)
            }
            
            self.rootVC.channelViewModel.isEditing = false
        }))
        rootVC.showBottomSheet(actions: actions, withCancel: true)
    }
    
    @objc
    open func clearChat() {
        showAlert(title: L10n.Channel.Selecting.clearChat,
                  message: L10n.Channel.Selecting.ClearChat.message,
                  actions: [
                    .init(title: L10n.Alert.Button.cancel, style: .cancel),
                    .init(title: L10n.Channel.Selecting.ClearChat.clear, style: .destructive) { [weak self] in
                        self?.rootVC.channelViewModel.deleteAllMessages(forMeOnly: false) { [weak self] error in
                            guard let self else { return }
                            if let error {
                                self.showAlert(error: error)
                            }
                            self.rootVC.channelViewModel.isEditing = false
                        }
                    }
                  ],
                  preferredActionIndex: 1)
    }
    
    open func showMessageInfo(layoutModel: MessageLayoutModel) {
        let viewController = Components.messageInfoVC.init()
        viewController.viewModel = Components.messageInfoVM.init(messageMarkerProvider: rootVC.channelViewModel.messageMarkerProvider, data: layoutModel)
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        rootVC.present(nav, animated: true)
    }
    
    open func showForward(_ handler: @escaping (([ChatChannel]) -> Void)) {
        let viewController = Components.forwardVC.init()
        viewController.viewModel = Components.channelForwardVM.init(handler: handler)
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        rootVC.present(nav, animated: true)
    }
}
