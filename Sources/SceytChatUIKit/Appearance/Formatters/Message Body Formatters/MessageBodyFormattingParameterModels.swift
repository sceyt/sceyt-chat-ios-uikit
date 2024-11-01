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
    let mentionLabelAppearance: LabelAppearance
    let deletedLabelAppearance: LabelAppearance
    let attachmentNameFormatter: any AttachmentFormatting
    let attachmentIconProvider: any AttachmentIconProviding
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
}
