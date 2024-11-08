//
//  RepliedMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 31.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class RepliedMessageBodyFormatter: RepliedMessageBodyFormatting {
    
    public init() {}
    
    open func format(_ messageBodyAttributes: RepliedMessageBodyFormatterAttributes) -> NSAttributedString {
        let message = messageBodyAttributes.message
        let attributedBody = NSAttributedString(string: message.body)// messageBodyAttributes.attributedBody
        
        if attributedBody.length > 0 {
            let attributedBody = attributedBody.mutableCopy() as! NSMutableAttributedString
            
            attributedBody.enumerateAttributes(in: NSRange(location: 0, length: attributedBody.length), using: { attributes, range, _ in
                var attributes = attributes
                attributes[.font] = messageBodyAttributes.bodyLabelAppearance.font
                attributes[.foregroundColor] = messageBodyAttributes.bodyLabelAppearance.foregroundColor
                if attributes.contains(where: { (key,_) in
                    key == .underlineColor
                }) {
                    attributes[.underlineColor] = messageBodyAttributes.bodyLabelAppearance.foregroundColor
                }
                attributedBody.setAttributes(attributes, range: range)
                message.bodyAttributes?
                    .filter { $0.type == .mention }
                    .sorted(by: { $0.offset > $1.offset })
                    .forEach { bodyAttribute in
                        let range = NSRange(location: bodyAttribute.offset, length: bodyAttribute.length)
                        if let userId = bodyAttribute.metadata,
                           let user = message.mentionedUsers?.first(where: { $0.id == userId }) {
                            var attributes = attributedBody.attributes(at: range.location, effectiveRange: nil)
                            attributes[.foregroundColor] = messageBodyAttributes.mentionLabelAppearance.foregroundColor
                            attributes[.font] = messageBodyAttributes.mentionLabelAppearance.font
                            attributes[.mention] = userId
                            let mention = NSAttributedString(string: SceytChatUIKit.shared.config.mentionTriggerPrefix + messageBodyAttributes.mentionUserNameFormatter.format(user),
                                                             attributes: attributes)
                            attributedBody.safeReplaceCharacters(in: range, with: mention)
                        }
                    }
            })
            return attributedBody
        } else {
            return makeBody(messageBodyAttributes)
        }
    }
    
    open func makeBody(_ messageBodyAttributes: RepliedMessageBodyFormatterAttributes) -> NSAttributedString {
        let message = messageBodyAttributes.message
        var body = message.body
        
        switch message.state {
        case .deleted:
            body = messageBodyAttributes.deletedStateText
            return .init(string: body, attributes: [
                .font: messageBodyAttributes.deletedLabelAppearance.font,
                .foregroundColor: messageBodyAttributes.deletedLabelAppearance.foregroundColor
            ])
        default:
            if body.isEmpty,
               let attachment = message.attachments?.first {
                switch MessageLayoutModel.AttachmentLayout.AttachmentType(rawValue: attachment.type) {
                case .image:
                    body = messageBodyAttributes.attachmentNameFormatter.format(attachment)
                case .video:
                    body = messageBodyAttributes.attachmentNameFormatter.format(attachment)
                case .voice:
                    let body = NSMutableAttributedString(string: messageBodyAttributes.attachmentNameFormatter.format(attachment),
                                                         attributes: [
                                                            .font: messageBodyAttributes.bodyLabelAppearance.font,
                                                            .foregroundColor: messageBodyAttributes.bodyLabelAppearance.foregroundColor
                                                         ])
                    body.append(.init(string: " \(messageBodyAttributes.attachmentDurationFormatter.format(Double(attachment.voiceDecodedMetadata?.duration ?? 0)))", attributes: [
                        .font: messageBodyAttributes.attachmentDurationLabelAppearance.font,
                        .foregroundColor: messageBodyAttributes.attachmentDurationLabelAppearance.foregroundColor
                    ]))
                    return body
                default:
                    body = messageBodyAttributes.attachmentNameFormatter.format(attachment)
                }
            }
            return .init(string: body, attributes: [
                .font: messageBodyAttributes.bodyLabelAppearance.font,
                .foregroundColor: messageBodyAttributes.bodyLabelAppearance.foregroundColor
            ])
        }
    }
}
