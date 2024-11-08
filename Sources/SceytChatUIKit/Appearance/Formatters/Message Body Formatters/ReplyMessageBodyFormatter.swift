//
//  ReplyMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 31.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class ReplyMessageBodyFormatter: ReplyMessageBodyFormatting {
    
    public init() {}
    
    open func format(_ messageBodyAttributes: ReplyMessageBodyFormatterAttributes) -> NSAttributedString {
        let message = messageBodyAttributes.message
        let bodyLabelAppearance = messageBodyAttributes.bodyLabelAppearance
        let mentionLabelAppearance = messageBodyAttributes.mentionLabelAppearance
        let attachmentDurationLabelAppearance = messageBodyAttributes.attachmentDurationLabelAppearance
        let attachmentDurationFormatter = messageBodyAttributes.attachmentDurationFormatter
        let attachmentNameFormatter = messageBodyAttributes.attachmentNameFormatter
        let mentionUserNameFormatter = messageBodyAttributes.mentionUserNameFormatter
        
        var text = message.body
        
        if let attachment = message.attachments?.first {
            switch attachment.type {
            case "image":
                if text.isEmpty {
                    text = attachmentNameFormatter.format(attachment)
                }
            case "video":
                if text.isEmpty {
                    text = attachmentNameFormatter.format(attachment)
                }
            case "voice":
                if text.isEmpty {
                    text = attachmentNameFormatter.format(attachment)
                }
            case "link":
                if text.isEmpty {
                    text = attachmentNameFormatter.format(attachment)
                }
            default:
                if text.isEmpty {
                    text = attachment.name ?? attachmentNameFormatter.format(attachment)
                }
            }
        }
        
        let messageAttributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: bodyLabelAppearance.font,
                .foregroundColor: bodyLabelAppearance.foregroundColor
            ])
        message.bodyAttributes?
            .filter { $0.type == .mention }
            .sorted(by: { $0.offset > $1.offset })
            .forEach { bodyAttribute in
                let range = NSRange(location: bodyAttribute.offset, length: bodyAttribute.length)
                if let userId = bodyAttribute.metadata,
                   let user = message.mentionedUsers?.first(where: { $0.id == userId }) {
                    var attributes = messageAttributedString.attributes(at: range.location, effectiveRange: nil)
                    attributes[.foregroundColor] = mentionLabelAppearance.foregroundColor
                    attributes[.font] = mentionLabelAppearance.font
                    attributes[.mention] = userId
                    let mention = NSAttributedString(string: SceytChatUIKit.shared.config.mentionTriggerPrefix + mentionUserNameFormatter.format(user),
                                                     attributes: attributes)
                    messageAttributedString.safeReplaceCharacters(in: range, with: mention)
                }
            }
        if let duration = message.attachments?.first?.voiceDecodedMetadata?.duration {
            messageAttributedString.append(.init(
                string: " " + attachmentDurationFormatter.format(TimeInterval(duration)),
                attributes: [
                    .font: attachmentDurationLabelAppearance.font,
                    .foregroundColor: attachmentDurationLabelAppearance.foregroundColor
                ]))
        }
        
        return messageAttributedString
    }
}
