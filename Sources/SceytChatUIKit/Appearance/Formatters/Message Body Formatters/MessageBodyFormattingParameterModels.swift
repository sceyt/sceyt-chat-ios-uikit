//
//  MessageBodyFormattingParameterModels.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 31.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

public struct MessageBodyFormatterAttributes {
    let message: ChatMessage
    let userSendMessage: UserSendMessage?
    let deletedStateText: String
    let bodyLabelAppearance: LabelAppearance
    let linkLabelAppearance: LabelAppearance
    let phoneNumberLabelAppearance: LabelAppearance
    let mentionLabelAppearance: LabelAppearance
    let deletedLabelAppearance: LabelAppearance
    let mentionUserNameFormatter: any UserFormatting
}

public struct LastMessageBodyFormatterAttributes {
    let message: ChatMessage
    let lastReaction: ChatMessage.Reaction?
    let deletedStateText: String
    let bodyLabelAppearance: LabelAppearance
    let linkLabelAppearance: LabelAppearance
    let phoneNumberLabelAppearance: LabelAppearance
    let mentionLabelAppearance: LabelAppearance
    let deletedLabelAppearance: LabelAppearance
    let attachmentNameFormatter: any AttachmentFormatting
    let attachmentIconProvider: any AttachmentIconProviding
    let messageTypeIconProvider: any MessageTypeIconProviding
    let mentionUserNameFormatter: any UserFormatting
}

public struct RepliedMessageBodyFormatterAttributes {
    let message: ChatMessage
    let deletedStateText: String
    let bodyLabelAppearance: LabelAppearance
    let mentionLabelAppearance: LabelAppearance
    let attachmentDurationLabelAppearance: LabelAppearance
    let deletedLabelAppearance: LabelAppearance
    let attachmentDurationFormatter: any TimeIntervalFormatting
    let attachmentNameFormatter: any AttachmentFormatting
    let mentionUserNameFormatter: any UserFormatting
    let replyUserNameFormatter: any UserFormatting
}

public struct EditMessageBodyFormatterAttributes {
    let message: ChatMessage
    let bodyLabelAppearance: LabelAppearance
    let mentionLabelAppearance: LabelAppearance
    let attachmentDurationLabelAppearance: LabelAppearance
    let attachmentDurationFormatter: any TimeIntervalFormatting
    let attachmentNameFormatter: any AttachmentFormatting
    let mentionUserNameFormatter: any UserFormatting
}

public struct ReplyMessageBodyFormatterAttributes {
    let message: ChatMessage
    let bodyLabelAppearance: LabelAppearance
    let mentionLabelAppearance: LabelAppearance
    let attachmentDurationLabelAppearance: LabelAppearance
    let attachmentDurationFormatter: any TimeIntervalFormatting
    let attachmentNameFormatter: any AttachmentFormatting
    let mentionUserNameFormatter: any UserFormatting
}

public struct DraftMessageBodyFormatterAttributes {
    let draftMessage: NSAttributedString
    let draftPrefixLabelAppearance: LabelAppearance
    let draftStateText: String
    let lastMessageLabelAppearance: LabelAppearance
    /// The draft's first attachment, when it has one. A draft can be attachments-only, in which
    /// case this is what the preview shows instead of the (empty) body.
    let draftAttachment: ChatMessage.Attachment?
    let attachmentNameFormatter: any AttachmentFormatting
    let attachmentIconProvider: any AttachmentIconProviding
    /// Already-localized label for a draft that carries only a reply/edit target and nothing to
    /// show — "Reply" / "Edit".
    let draftActionText: String?

    // Internal, matching the memberwise init this struct had before the attachment fields were
    // added — the properties are internal, so it was never constructible from outside the module.
    init(
        draftMessage: NSAttributedString,
        draftPrefixLabelAppearance: LabelAppearance,
        draftStateText: String,
        lastMessageLabelAppearance: LabelAppearance,
        draftAttachment: ChatMessage.Attachment? = nil,
        attachmentNameFormatter: any AttachmentFormatting,
        attachmentIconProvider: any AttachmentIconProviding,
        draftActionText: String? = nil
    ) {
        self.draftMessage = draftMessage
        self.draftPrefixLabelAppearance = draftPrefixLabelAppearance
        self.draftStateText = draftStateText
        self.lastMessageLabelAppearance = lastMessageLabelAppearance
        self.draftAttachment = draftAttachment
        self.attachmentNameFormatter = attachmentNameFormatter
        self.attachmentIconProvider = attachmentIconProvider
        self.draftActionText = draftActionText
    }
}
