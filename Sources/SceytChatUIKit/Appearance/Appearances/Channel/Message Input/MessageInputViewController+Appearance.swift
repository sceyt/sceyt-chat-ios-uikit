//
//  MessageInputViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .background
        public var dividerColor: UIColor = .border
        public var attachmentIcon: UIImage = .attachment
        public var sendMessageIcon: UIImage = .messageSendAction
        public var voiceRecordIcon: UIImage = .audioPlayerMic
        public var sendVoiceMessageIcon: UIImage = .messageSendAction
        public var enableVoiceRecord: Bool = true
        public var enableSendAttachment: Bool = true
        public var enableMention: Bool = true
        public var inputAppearance: InputTextView.Appearance = .init()
        public var mentionLabelAppearance: LabelAppearance = .init(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(16)
        )
        public var joinButtonAppearance: ButtonAppearance = .init(
            labelAppearance: .init(
                foregroundColor: .accent,
                font: Fonts.semiBold.withSize(16)
            ),
            backgroundColor: .surface1
        )
        public var selectedAttachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
        public var closeIcon: UIImage = .closeIcon
        public var linkPreviewAppearance: InputLinkPreviewAppearance = .init(backgroundColor: .surface1)
        public var replyMessageAppearance: InputReplyMessageAppearance = .init()
        public var editMessageAppearance: InputEditMessageAppearance = .init()
        public var selectedMediaAppearance: SelectedMediaView.Appearance = SelectedMediaView.appearance
        public var voiceRecorderAppearance: VoiceRecorderView.Appearance = VoiceRecorderView.appearance
        public var voiceRecordPlaybackAppearance: VoiceRecordPlaybackView.Appearance = VoiceRecordPlaybackView.appearance
        public var mentionUsersListAppearance: MentionUsersListViewController.Appearance = MentionUsersListViewController.appearance
        public var messageSearchControlsAppearance: MessageSearchControlsView.Appearance = MessageSearchControlsView.appearance
        public var coverAppearance: CoverView.Appearance = CoverView.appearance
        public var selectedMessagesActionsAppearance: SelectedMessagesActionsView.Appearance = SelectedMessagesActionsView.appearance
        public var mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .background,
            dividerColor: UIColor = .border,
            attachmentIcon: UIImage = .attachment,
            sendMessageIcon: UIImage = .messageSendAction,
            voiceRecordIcon: UIImage = .audioPlayerMic,
            sendVoiceMessageIcon: UIImage = .messageSendAction,
            enableVoiceRecord: Bool = true,
            enableSendAttachment: Bool = true,
            enableMention: Bool = true,
            inputAppearance: InputTextView.Appearance = .init(),
            mentionLabelAppearance: LabelAppearance = .init(
                foregroundColor: .accent,
                font: Fonts.regular.withSize(16)
            ),
            joinButtonAppearance: ButtonAppearance = .init(
                labelAppearance: .init(
                    foregroundColor: .accent,
                    font: Fonts.semiBold.withSize(16)
                ),
                backgroundColor: .surface1
            ),
            selectedAttachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
            closeIcon: UIImage = .closeIcon,
            linkPreviewAppearance: InputLinkPreviewAppearance = .init(backgroundColor: .surface1),
            replyMessageAppearance: InputReplyMessageAppearance = .init(),
            editMessageAppearance: InputEditMessageAppearance = .init(),
            selectedMediaAppearance: SelectedMediaView.Appearance = SelectedMediaView.appearance,
            voiceRecorderAppearance: VoiceRecorderView.Appearance = VoiceRecorderView.appearance,
            voiceRecordPlaybackAppearance: VoiceRecordPlaybackView.Appearance = VoiceRecordPlaybackView.appearance,
            mentionUsersListAppearance: MentionUsersListViewController.Appearance = MentionUsersListViewController.appearance,
            messageSearchControlsAppearance: MessageSearchControlsView.Appearance = MessageSearchControlsView.appearance,
            coverAppearance: CoverView.Appearance = CoverView.appearance,
            selectedMessagesActionsAppearance: SelectedMessagesActionsView.Appearance = SelectedMessagesActionsView.appearance,
            mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
        ) {
            self.backgroundColor = backgroundColor
            self.dividerColor = dividerColor
            self.attachmentIcon = attachmentIcon
            self.sendMessageIcon = sendMessageIcon
            self.voiceRecordIcon = voiceRecordIcon
            self.sendVoiceMessageIcon = sendVoiceMessageIcon
            self.enableVoiceRecord = enableVoiceRecord
            self.enableSendAttachment = enableSendAttachment
            self.enableMention = enableMention
            self.inputAppearance = inputAppearance
            self.mentionLabelAppearance = mentionLabelAppearance
            self.joinButtonAppearance = joinButtonAppearance
            self.selectedAttachmentIconProvider = selectedAttachmentIconProvider
            self.closeIcon = closeIcon
            self.linkPreviewAppearance = linkPreviewAppearance
            self.replyMessageAppearance = replyMessageAppearance
            self.editMessageAppearance = editMessageAppearance
            self.selectedMediaAppearance = selectedMediaAppearance
            self.voiceRecorderAppearance = voiceRecorderAppearance
            self.voiceRecordPlaybackAppearance = voiceRecordPlaybackAppearance
            self.mentionUsersListAppearance = mentionUsersListAppearance
            self.messageSearchControlsAppearance = messageSearchControlsAppearance
            self.coverAppearance = coverAppearance
            self.selectedMessagesActionsAppearance = selectedMessagesActionsAppearance
            self.mentionUserNameFormatter = mentionUserNameFormatter
        }
    }
}
