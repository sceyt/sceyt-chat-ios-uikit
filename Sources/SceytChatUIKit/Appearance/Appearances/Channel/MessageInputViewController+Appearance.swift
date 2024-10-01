//
//  MessageInputViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .background
        public lazy var dividerColor: UIColor = .border
        public lazy var attachmentIcon: UIImage = .attachment
        public lazy var sendMessageIcon: UIImage = .messageSendAction
        public lazy var voiceRecordIcon: UIImage = .audioPlayerMic
        public lazy var sendVoiceMessageIcon: UIImage = .messageSendAction
        public lazy var enableVoiceRecord: Bool = true
        public lazy var enableSendAttachment: Bool = true
        public lazy var enableMention: Bool = true
        public lazy var inputAppearance: InputTextView.Appearance = .init()
        public lazy var mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                        font: Fonts.regular.withSize(16))
        public lazy var joinButtonAppearance: ButtonAppearance = .init(labelAppearance: .init(foregroundColor: .accent,
                                                                                              font: Fonts.semiBold.withSize(16)),
                                                                       backgroundColor: .surface1)
        public lazy var selectedAttachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
        public lazy var closeIcon: UIImage = .closeIcon
        public lazy var linkPreviewAppearance: InputLinkPreviewAppearance = .init(backgroundColor: .surface1)
        public lazy var replyMessageAppearance: InputReplyMessageAppearance = .init()
        public lazy var editMessageAppearance: InputEditMessageAppearance = .init()
        public lazy var selectedMediaAppearance: SelectedMediaView.Appearance = SelectedMediaView.appearance
        public lazy var voiceRecorderAppearance: VoiceRecorderView.Appearance = VoiceRecorderView.appearance
        public lazy var voiceRecordPlaybackAppearance: VoiceRecordPlaybackView.Appearance = VoiceRecordPlaybackView.appearance
        public lazy var mentionUsersListAppearance: MentionUsersListViewController.Appearance = MentionUsersListViewController.appearance
        public lazy var messageSearchControlsAppearance: MessageSearchControlsView.Appearance = MessageSearchControlsView.appearance
        public lazy var coverAppearance: CoverView.Appearance = CoverView.appearance
        public lazy var selectedMessagesActionsAppearance: SelectedMessagesActionsView.Appearance = SelectedMessagesActionsView.appearance
        public lazy var mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
        
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
            mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                            font: Fonts.regular.withSize(16)),
            joinButtonAppearance: ButtonAppearance = .init(labelAppearance: .init(foregroundColor: .accent,
                                                                                  font: Fonts.semiBold.withSize(16)),
                                                           backgroundColor: .surface1),
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
