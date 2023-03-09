//
//  ChannelRouter.swift
//  SceytChatUIKit
//

import AVKit
import UIKit

open class ChannelRouter: Router<ChannelVC> {
    open func showThreadForMessage(at indexPath: IndexPath) {
        // MARK: 3

        guard let message = rootVC.channelViewModel.message(at: indexPath)
        else { return }
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
        let profileVC = Components.channelProfileVC.init()
        profileVC.profileViewModel = Components.channelProfileVM
            .init(
                channel: rootVC.channelViewModel.channel
            )
        rootVC.show(profileVC, sender: self)
    }

    open func showAttachments(
        messageAt indexPath: IndexPath,
        from position: Int
    ) {
        guard let message = rootVC.channelViewModel.message(at: indexPath),
              let attachments = message.attachments?.filter({ !$0.originUrl.isVideo && !$0.originUrl.isAudio }),
              !attachments.isEmpty
        else { return }

        let preview = FilePreviewController(
            items: AttachmentView.items(attachments: attachments)
                .map { .init(title: $0.name, url: $0.url) },
            selected: position
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
        let alert = UIAlertController(title: L10n.Message.Alert.Delete.title,
                                      message: L10n.Message.Alert.Delete.description,
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: L10n.Alert.Button.cancel, style: .cancel) { _ in
            confirmed(false)
        })

        alert.addAction(UIAlertAction(title: L10n.Alert.Button.delete, style: .destructive) { _ in
            confirmed(true)
        })

        rootVC.present(alert, animated: true)
    }

    open func showEmojis() -> EmojiVC {
        let emojiVC = EmojiVC
            .init()
        let nav = EmojiViewInteractiveTransitionNavigationController
            .init(rootViewController: emojiVC)
        rootVC.present(nav, animated: true)
        return emojiVC
    }

    @available(iOSApplicationExtension, unavailable)
    open func showLink(_ link: URL) {
        UIApplication.shared.open(link)
    }

    open func playFrom(url: URL) {
        let player = AVPlayer(url: url)
        let vc = AVPlayerViewController()
        vc.player = player

        rootVC.present(vc, animated: true) {
            vc.player?.play()
        }
    }

    @discardableResult
    open func showReactions(
        reactionScores: [String: Int],
        reactions: [ChatMessage.Reaction]
    ) -> ReactionVC {
        let reactionPageVC = ReactionVC
            .init()
        let reactionScoreViewModel = ReactionScoreViewModel(reactionScores: reactionScores)
        var userReactionViewModels: [UserReactionViewModel] = [.init(reactions: reactions)]
        let keyUserReactionViewModels = reactionScores
            .sorted(by: { $0.value > $1.value })
            .map { key, value in
                let reactionsForKey = reactions.filter { $0.key == key }
                return UserReactionViewModel(reactions: reactionsForKey)
            }
        userReactionViewModels.append(contentsOf: keyUserReactionViewModels)
        reactionPageVC.reactionScoreViewModel = reactionScoreViewModel
        reactionPageVC.userReactionsViewModel = userReactionViewModels
        reactionPageVC.modalPresentationStyle = .custom
        rootVC.present(reactionPageVC, animated: true)
        return reactionPageVC
    }

}
