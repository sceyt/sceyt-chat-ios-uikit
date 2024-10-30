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

open class ChannelRouter: Router<ChannelViewController> {
    open func showThreadForMessage(_ message: ChatMessage) {
        let chatViewController = Components.channelViewController.init()
        chatViewController.channelViewModel = Components.channelViewModel
            .init(
                channel: rootViewController.channelViewModel.channel,
                threadMessage: message
            )
        chatViewController.hidesBottomBarWhenPushed = true
        rootViewController.show(chatViewController, sender: self)
    }

    open func showChannelProfile() {
        let profileViewController = Components.channelInfoViewController.init()
        profileViewController.profileViewModel = Components.channelProfileViewModel
            .init(
                channel: rootViewController.channelViewModel.channel,
                appearance: MessageCell.appearance
            )
        rootViewController.show(profileViewController, sender: self)
    }

    open func showAttachment(_ attachment: ChatMessage.Attachment) {
        
        let items = AttachmentModel.items(attachments: [attachment])
        guard !items.isEmpty else { return }
        let preview = FilePreviewController(
            items: items
                .map { .init(title: $0.name, url: $0.url) }
        )
        
        let isFirstResponder = rootViewController.inputTextView.isFirstResponder
        rootViewController.inputTextView.resignFirstResponder()
        preview.present(on: rootViewController) { [weak self] in
            guard let self else { return }
            if isFirstResponder, case .didDismiss = $0 {
                self.rootViewController.inputTextView.becomeFirstResponder()
            }
        }
    }

    open func showConfirmationAlertForDeleteMessage(
        _ confirmed: @escaping (Bool) -> Void
    ) {
        rootViewController.showAlert(
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

    open func showEmojis() -> EmojiPickerViewController {
        let emojiPickerViewController = Components.emojiPickerViewController.init()
        emojiPickerViewController.viewModel = Components.emojiListViewModel.init()
        let nav = EmojiViewInteractiveTransitionNavigationController
            .init(rootViewController: emojiPickerViewController)
        rootViewController.present(nav, animated: true)
        return emojiPickerViewController
    }

    open func playFrom(url: URL) {
        let player = AVPlayer(url: url)
        let viewController = AVPlayerViewController()
        viewController.player = player

        rootViewController.present(viewController, animated: true) {
            viewController.player?.play()
        }
    }

    @discardableResult
    open func showReactions(
        message: ChatMessage
    ) -> ReactionsInfoViewController {
        let reactionPageViewController = Components.reactionsInfoViewController.init()
        let reactionScores = message.reactionScores?.sorted(by: { $0.key > $1.key && $0.value > $1.value }) ?? []
        let reactionScoreViewModel = Components.reactionScoreViewModel.init(reactionScores: reactionScores)
        var userReactionViewModels: [UserReactionViewModel] = .init()
        userReactionViewModels.reserveCapacity(reactionScores.count + 1)
        userReactionViewModels.append(Components.userReactionViewModel.init(messageId: message.id, reactionKey: nil))
        reactionScores.forEach { key, _ in
            userReactionViewModels.append(Components.userReactionViewModel.init(messageId: message.id, reactionKey: key))
        }
        reactionPageViewController.reactionScoreViewModel = reactionScoreViewModel
        reactionPageViewController.userReactionsViewModel = userReactionViewModels
        reactionPageViewController.modalPresentationStyle = .custom
        rootViewController.present(reactionPageViewController, animated: true)
        return reactionPageViewController
    }
    
    open func showChannelInfoViewController(channel: ChatChannel) {
        let viewController = Components.channelInfoViewController.init()
        viewController.hidesBottomBarWhenPushed = true
        viewController.profileViewModel = Components.channelProfileViewModel.init(channel: channel, appearance: MessageCell.appearance)
        self.rootViewController.show(viewController, sender: self)
    }
    
    open func showDeleteOptions(clear: Bool) {
        var actions = [SheetAction]()
        actions.append(.init(title: L10n.Message.Action.Subtitle.deleteAll,
                             icon: .chatDelete,
                             style: .destructive,
                             handler: { [weak self] in
            guard let self else { return }
            if clear {
                self.rootViewController.channelViewModel.deleteAllMessages(forMeOnly: false) { [weak self] error in
                    guard let self else { return }
                    if let error {
                        self.showAlert(error: error)
                    }
                }
            } else {
                self.rootViewController.channelViewModel.deleteSelectedMessages(type: SceytChatUIKit.shared.config.hardDeleteMessageForAll ? .deleteHard : .deleteForEveryone)
            }
            
            self.rootViewController.channelViewModel.isEditing = false
        }))
        actions.append(.init(title: L10n.Message.Action.Subtitle.deleteMe,
                             icon: .chatDelete,
                             style: .destructive,
                             handler: { [weak self] in
            guard let self else { return }
            if clear {
                self.rootViewController.channelViewModel.deleteAllMessages(forMeOnly: true) { [weak self] error in
                    guard let self else { return }
                    if let error {
                        self.showAlert(error: error)
                    }
                }
            } else {
                self.rootViewController.channelViewModel.deleteSelectedMessages(type: .deleteForMe)
            }
            
            self.rootViewController.channelViewModel.isEditing = false
        }))
        rootViewController.showBottomSheet(actions: actions, withCancel: true)
    }
    
    @objc
    open func clearChat() {
        showAlert(title: L10n.Channel.Selecting.clearChat,
                  message: L10n.Channel.Selecting.ClearChat.message,
                  actions: [
                    .init(title: L10n.Alert.Button.cancel, style: .cancel),
                    .init(title: L10n.Channel.Selecting.ClearChat.clear, style: .destructive) { [weak self] in
                        self?.rootViewController.channelViewModel.deleteAllMessages(forMeOnly: false) { [weak self] error in
                            guard let self else { return }
                            if let error {
                                self.showAlert(error: error)
                            }
                            self.rootViewController.channelViewModel.isEditing = false
                        }
                    }
                  ],
                  preferredActionIndex: 1)
    }
    
    open func showMessageInfo(layoutModel: MessageLayoutModel, messageCellAppearance: MessageCellAppearance? = nil) {
        let viewController = Components.messageInfoViewController.init(messageCellAppearance: messageCellAppearance)
        viewController.viewModel = Components.messageInfoViewModel.init(messageMarkerProvider: rootViewController.channelViewModel.messageMarkerProvider, data: layoutModel)
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        rootViewController.present(nav, animated: true)
    }
    
    open func showForward(_ handler: @escaping (([ChatChannel]) -> Void)) {
        let viewController = Components.forwardViewController.init()
        viewController.viewModel = Components.channelForwardViewModel.init(handler: handler)
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        rootViewController.present(nav, animated: true)
    }
}
