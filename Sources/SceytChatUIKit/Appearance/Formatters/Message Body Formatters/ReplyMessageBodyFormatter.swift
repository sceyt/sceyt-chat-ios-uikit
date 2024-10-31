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
        let message = messageBodyAttributes.layoutModel.message
        let bodyLabelAppearance = messageBodyAttributes.bodyLabelAppearance
        let mentionLabelAppearance = messageBodyAttributes.mentionLabelAppearance
        let attachmentDurationLabelAppearance = messageBodyAttributes.attachmentDurationLabelAppearance
        let attachmentDurationFormatter = messageBodyAttributes.attachmentDurationFormatter
        let attachmentNameFormatter = messageBodyAttributes.attachmentNameFormatter
        
        
        var text = messageBodyAttributes.layoutModel.attributedView.content.string.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
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
                var mentionAttributes: [NSAttributedString.Key : Any] = [:]
                mentionAttributes[.font] = mentionLabelAppearance.font
                mentionAttributes[.foregroundColor] = mentionLabelAppearance.foregroundColor
                
                if range.location >= 0 && (range.location + range.length) <= messageAttributedString.length {
                    messageAttributedString.setAttributes(mentionAttributes, range: range)
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
