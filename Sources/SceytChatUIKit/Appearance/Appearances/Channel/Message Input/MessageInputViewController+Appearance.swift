//
//  MessageInputViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24
//

import UIKit

extension MessageInputViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        separatorColor: .border,
        attachmentIcon: .attachment,
        sendMessageIcon: .messageSendAction,
        voiceRecordIcon: .audioPlayerMic,
        sendVoiceMessageIcon: .messageSendAction,
        enableVoiceRecord: true,
        enableSendAttachment: true,
        enableMention: true,
        inputAppearance: InputTextView.Appearance(
            reference: InputTextView.appearance
        ),
        mentionLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(16)
        ),
        joinButtonAppearance: ButtonAppearance(
            reference: ButtonAppearance.appearance,
            labelAppearance: LabelAppearance(
                foregroundColor: .accent,
                font: Fonts.semiBold.withSize(16)
            ),
            backgroundColor: .surface1
        ),
        closeIcon: .closeIcon,
        linkPreviewAppearance: InputLinkPreviewAppearance(
            reference: InputLinkPreviewAppearance.appearance,
            backgroundColor: .surface1
        ),
        replyMessageAppearance: InputReplyMessageAppearance(
            reference: InputReplyMessageAppearance.appearance
        ),
        editMessageAppearance: InputEditMessageAppearance(
            reference: InputEditMessageAppearance.appearance
        ),
        selectedMediaAppearance: SelectedMediaView.appearance,
        voiceRecorderAppearance: VoiceRecorderView.appearance,
        voiceRecordPlaybackAppearance: VoiceRecordPlaybackView.appearance,
        mentionUsersListAppearance: MentionUsersListViewController.appearance,
        messageSearchControlsAppearance: MessageSearchControlsView.appearance,
        coverAppearance: CoverView.appearance,
        selectedMessagesActionsAppearance: SelectedMessagesActionsView.appearance,
        mentionUserNameFormatter: SceytChatUIKit.shared.formatters.userNameFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, UIImage>
        public var attachmentIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var sendMessageIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var voiceRecordIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var sendVoiceMessageIcon: UIImage
        
        @Trackable<Appearance, Bool>
        public var enableVoiceRecord: Bool
        
        @Trackable<Appearance, Bool>
        public var enableSendAttachment: Bool
        
        @Trackable<Appearance, Bool>
        public var enableMention: Bool
        
        @Trackable<Appearance, InputTextView.Appearance>
        public var inputAppearance: InputTextView.Appearance
        
        @Trackable<Appearance, LabelAppearance>
        public var mentionLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, ButtonAppearance>
        public var joinButtonAppearance: ButtonAppearance
        
        @Trackable<Appearance, UIImage>
        public var closeIcon: UIImage
        
        @Trackable<Appearance, InputLinkPreviewAppearance>
        public var linkPreviewAppearance: InputLinkPreviewAppearance
        
        @Trackable<Appearance, InputReplyMessageAppearance>
        public var replyMessageAppearance: InputReplyMessageAppearance
        
        @Trackable<Appearance, InputEditMessageAppearance>
        public var editMessageAppearance: InputEditMessageAppearance
        
        @Trackable<Appearance, SelectedMediaView.Appearance>
        public var selectedMediaAppearance: SelectedMediaView.Appearance
        
        @Trackable<Appearance, VoiceRecorderView.Appearance>
        public var voiceRecorderAppearance: VoiceRecorderView.Appearance
        
        @Trackable<Appearance, VoiceRecordPlaybackView.Appearance>
        public var voiceRecordPlaybackAppearance: VoiceRecordPlaybackView.Appearance
        
        @Trackable<Appearance, MentionUsersListViewController.Appearance>
        public var mentionUsersListAppearance: MentionUsersListViewController.Appearance
        
        @Trackable<Appearance, MessageSearchControlsView.Appearance>
        public var messageSearchControlsAppearance: MessageSearchControlsView.Appearance
        
        @Trackable<Appearance, CoverView.Appearance>
        public var coverAppearance: CoverView.Appearance
        
        @Trackable<Appearance, SelectedMessagesActionsView.Appearance>
        public var selectedMessagesActionsAppearance: SelectedMessagesActionsView.Appearance
        
        @Trackable<Appearance, any UserFormatting>
        public var mentionUserNameFormatter: any UserFormatting
        
        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            attachmentIcon: UIImage,
            sendMessageIcon: UIImage,
            voiceRecordIcon: UIImage,
            sendVoiceMessageIcon: UIImage,
            enableVoiceRecord: Bool,
            enableSendAttachment: Bool,
            enableMention: Bool,
            inputAppearance: InputTextView.Appearance,
            mentionLabelAppearance: LabelAppearance,
            joinButtonAppearance: ButtonAppearance,
            closeIcon: UIImage,
            linkPreviewAppearance: InputLinkPreviewAppearance,
            replyMessageAppearance: InputReplyMessageAppearance,
            editMessageAppearance: InputEditMessageAppearance,
            selectedMediaAppearance: SelectedMediaView.Appearance,
            voiceRecorderAppearance: VoiceRecorderView.Appearance,
            voiceRecordPlaybackAppearance: VoiceRecordPlaybackView.Appearance,
            mentionUsersListAppearance: MentionUsersListViewController.Appearance,
            messageSearchControlsAppearance: MessageSearchControlsView.Appearance,
            coverAppearance: CoverView.Appearance,
            selectedMessagesActionsAppearance: SelectedMessagesActionsView.Appearance,
            mentionUserNameFormatter: any UserFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._attachmentIcon = Trackable(value: attachmentIcon)
            self._sendMessageIcon = Trackable(value: sendMessageIcon)
            self._voiceRecordIcon = Trackable(value: voiceRecordIcon)
            self._sendVoiceMessageIcon = Trackable(value: sendVoiceMessageIcon)
            self._enableVoiceRecord = Trackable(value: enableVoiceRecord)
            self._enableSendAttachment = Trackable(value: enableSendAttachment)
            self._enableMention = Trackable(value: enableMention)
            self._inputAppearance = Trackable(value: inputAppearance)
            self._mentionLabelAppearance = Trackable(value: mentionLabelAppearance)
            self._joinButtonAppearance = Trackable(value: joinButtonAppearance)
            self._closeIcon = Trackable(value: closeIcon)
            self._linkPreviewAppearance = Trackable(value: linkPreviewAppearance)
            self._replyMessageAppearance = Trackable(value: replyMessageAppearance)
            self._editMessageAppearance = Trackable(value: editMessageAppearance)
            self._selectedMediaAppearance = Trackable(value: selectedMediaAppearance)
            self._voiceRecorderAppearance = Trackable(value: voiceRecorderAppearance)
            self._voiceRecordPlaybackAppearance = Trackable(value: voiceRecordPlaybackAppearance)
            self._mentionUsersListAppearance = Trackable(value: mentionUsersListAppearance)
            self._messageSearchControlsAppearance = Trackable(value: messageSearchControlsAppearance)
            self._coverAppearance = Trackable(value: coverAppearance)
            self._selectedMessagesActionsAppearance = Trackable(value: selectedMessagesActionsAppearance)
            self._mentionUserNameFormatter = Trackable(value: mentionUserNameFormatter)
        }
        
        public init(
            reference: MessageInputViewController.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            attachmentIcon: UIImage? = nil,
            sendMessageIcon: UIImage? = nil,
            voiceRecordIcon: UIImage? = nil,
            sendVoiceMessageIcon: UIImage? = nil,
            enableVoiceRecord: Bool? = nil,
            enableSendAttachment: Bool? = nil,
            enableMention: Bool? = nil,
            inputAppearance: InputTextView.Appearance? = nil,
            mentionLabelAppearance: LabelAppearance? = nil,
            joinButtonAppearance: ButtonAppearance? = nil,
            closeIcon: UIImage? = nil,
            linkPreviewAppearance: InputLinkPreviewAppearance? = nil,
            replyMessageAppearance: InputReplyMessageAppearance? = nil,
            editMessageAppearance: InputEditMessageAppearance? = nil,
            selectedMediaAppearance: SelectedMediaView.Appearance? = nil,
            voiceRecorderAppearance: VoiceRecorderView.Appearance? = nil,
            voiceRecordPlaybackAppearance: VoiceRecordPlaybackView.Appearance? = nil,
            mentionUsersListAppearance: MentionUsersListViewController.Appearance? = nil,
            messageSearchControlsAppearance: MessageSearchControlsView.Appearance? = nil,
            coverAppearance: CoverView.Appearance? = nil,
            selectedMessagesActionsAppearance: SelectedMessagesActionsView.Appearance? = nil,
            mentionUserNameFormatter: (any UserFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._attachmentIcon = Trackable(reference: reference, referencePath: \.attachmentIcon)
            self._sendMessageIcon = Trackable(reference: reference, referencePath: \.sendMessageIcon)
            self._voiceRecordIcon = Trackable(reference: reference, referencePath: \.voiceRecordIcon)
            self._sendVoiceMessageIcon = Trackable(reference: reference, referencePath: \.sendVoiceMessageIcon)
            self._enableVoiceRecord = Trackable(reference: reference, referencePath: \.enableVoiceRecord)
            self._enableSendAttachment = Trackable(reference: reference, referencePath: \.enableSendAttachment)
            self._enableMention = Trackable(reference: reference, referencePath: \.enableMention)
            self._inputAppearance = Trackable(reference: reference, referencePath: \.inputAppearance)
            self._mentionLabelAppearance = Trackable(reference: reference, referencePath: \.mentionLabelAppearance)
            self._joinButtonAppearance = Trackable(reference: reference, referencePath: \.joinButtonAppearance)
            self._closeIcon = Trackable(reference: reference, referencePath: \.closeIcon)
            self._linkPreviewAppearance = Trackable(reference: reference, referencePath: \.linkPreviewAppearance)
            self._replyMessageAppearance = Trackable(reference: reference, referencePath: \.replyMessageAppearance)
            self._editMessageAppearance = Trackable(reference: reference, referencePath: \.editMessageAppearance)
            self._selectedMediaAppearance = Trackable(reference: reference, referencePath: \.selectedMediaAppearance)
            self._voiceRecorderAppearance = Trackable(reference: reference, referencePath: \.voiceRecorderAppearance)
            self._voiceRecordPlaybackAppearance = Trackable(reference: reference, referencePath: \.voiceRecordPlaybackAppearance)
            self._mentionUsersListAppearance = Trackable(reference: reference, referencePath: \.mentionUsersListAppearance)
            self._messageSearchControlsAppearance = Trackable(reference: reference, referencePath: \.messageSearchControlsAppearance)
            self._coverAppearance = Trackable(reference: reference, referencePath: \.coverAppearance)
            self._selectedMessagesActionsAppearance = Trackable(reference: reference, referencePath: \.selectedMessagesActionsAppearance)
            self._mentionUserNameFormatter = Trackable(reference: reference, referencePath: \.mentionUserNameFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let attachmentIcon { self.attachmentIcon = attachmentIcon }
            if let sendMessageIcon { self.sendMessageIcon = sendMessageIcon }
            if let voiceRecordIcon { self.voiceRecordIcon = voiceRecordIcon }
            if let sendVoiceMessageIcon { self.sendVoiceMessageIcon = sendVoiceMessageIcon }
            if let enableVoiceRecord { self.enableVoiceRecord = enableVoiceRecord }
            if let enableSendAttachment { self.enableSendAttachment = enableSendAttachment }
            if let enableMention { self.enableMention = enableMention }
            if let inputAppearance { self.inputAppearance = inputAppearance }
            if let mentionLabelAppearance { self.mentionLabelAppearance = mentionLabelAppearance }
            if let joinButtonAppearance { self.joinButtonAppearance = joinButtonAppearance }
            if let closeIcon { self.closeIcon = closeIcon }
            if let linkPreviewAppearance { self.linkPreviewAppearance = linkPreviewAppearance }
            if let replyMessageAppearance { self.replyMessageAppearance = replyMessageAppearance }
            if let editMessageAppearance { self.editMessageAppearance = editMessageAppearance }
            if let selectedMediaAppearance { self.selectedMediaAppearance = selectedMediaAppearance }
            if let voiceRecorderAppearance { self.voiceRecorderAppearance = voiceRecorderAppearance }
            if let voiceRecordPlaybackAppearance { self.voiceRecordPlaybackAppearance = voiceRecordPlaybackAppearance }
            if let mentionUsersListAppearance { self.mentionUsersListAppearance = mentionUsersListAppearance }
            if let messageSearchControlsAppearance { self.messageSearchControlsAppearance = messageSearchControlsAppearance }
            if let coverAppearance { self.coverAppearance = coverAppearance }
            if let selectedMessagesActionsAppearance { self.selectedMessagesActionsAppearance = selectedMessagesActionsAppearance }
            if let mentionUserNameFormatter { self.mentionUserNameFormatter = mentionUserNameFormatter }
        }
    }
}
