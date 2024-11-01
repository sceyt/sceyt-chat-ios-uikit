//
//  ChannelLastMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 31.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelLastMessageBodyFormatter: MessageBodyFormatting {
    
    public init() {}
    
    open func format(_ messageBodyAttributes: MessageBodyFormatterAttributes) -> NSAttributedString {
        let message = messageBodyAttributes.message
        
        switch message.state {
        case .deleted:
            return NSAttributedString(
                string: messageBodyAttributes.deletedStateText,
                attributes: [
                    .font: messageBodyAttributes.deletedLabelAppearance.font,
                    .foregroundColor: messageBodyAttributes.deletedLabelAppearance.foregroundColor
                ]
            )
        default:
            let bodyFont = messageBodyAttributes.bodyLabelAppearance.font
            let bodyColor = messageBodyAttributes.bodyLabelAppearance.foregroundColor
            let mentionFont = messageBodyAttributes.mentionLabelAppearance.font
            let mentionColor = messageBodyAttributes.mentionLabelAppearance.foregroundColor
            let linkColor = messageBodyAttributes.linkLabelAppearance.foregroundColor
            let linkFont = messageBodyAttributes.linkLabelAppearance.font
            
            var content = message.body.replacingOccurrences(of: "\n", with: " ")
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(
                    string: content,
                    attributes: [
                        .font: bodyFont,
                        .foregroundColor: bodyColor
                    ]
                )
            )
            
            let matches = DataDetector.matches(text: content)
            for match in matches {
                let linkAttributes: [NSAttributedString.Key : Any] = [
                    .font: linkFont,
                    .foregroundColor: linkColor,
                    .underlineColor: linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                text.addAttributes(linkAttributes, range: match.range)
            }
            
            let mentionedUsers = message.mentionedUsers?.map { ($0.id, messageBodyAttributes.mentionUserNameFormatter.format($0)) }
            if let mentionedUsers = mentionedUsers, mentionedUsers.count > 0,
               let metadata = message.metadata?.data(using: .utf8),
               let ranges = try? JSONDecoder().decode([MentionUserPos].self, from: metadata) {
                var lengths = 0
                for pos in ranges.reversed() {
                    if let user = mentionedUsers.last(where: { $0.0 == pos.id }), pos.loc >= 0 {
                        let attributes: [NSAttributedString.Key : Any] = [.font: mentionFont,
                                                                          .foregroundColor: mentionColor,
                                                                          .mention: pos.id]
                        let mention = NSAttributedString(string: SceytChatUIKit.shared.config.mentionTriggerPrefix + user.1,
                                                         attributes: attributes)
                        guard text.length >= pos.loc + pos.len else {
                            logger.debug("Something wrong❗️❗️❗️body: \(text.string) mention: \(mention.string) pos: \(pos.loc) \(pos.len) user: \(pos.id)")
                            continue
                        }
                        text.safeReplaceCharacters(in: .init(location: pos.loc, length: pos.len), with: mention)
                        lengths += mention.length
                    }
                }
            }
            
            if !content.isEmpty, let bodyAttributes = message.bodyAttributes {
                bodyAttributes.reduce([NSRange: [ChatMessage.BodyAttribute]]()) { partialResult, bodyAttribute in
                    let location = max(0, min(text.length - 1, bodyAttribute.offset))
                    let length = max(0, min(text.length - location, bodyAttribute.length))
                    let range = NSRange(location: location, length: length)
                    var array = partialResult[range] ?? []
                    array.append(bodyAttribute)
                    var partialResult = partialResult
                    partialResult[range] = array
                    return partialResult
                }.forEach { range, value in
                    var font = bodyFont
                    if value.contains(where: { $0.type == .monospace }) {
                        font = font.toMonospace
                    }
                    if value.contains(where: { $0.type == .bold }) {
                        font = font.toSemiBold
                    }
                    if value.contains(where: { $0.type == .italic }) {
                        font = font.toItalic
                    }
                    if value.contains(where: { $0.type == .strikethrough }) {
                        text.addAttributes([.strikethroughStyle : NSUnderlineStyle.single.rawValue], range: range)
                    }
                    if value.contains(where: { $0.type == .underline }) {
                        text.addAttributes([.underlineStyle : NSUnderlineStyle.single.rawValue], range: range)
                    }
                    text.addAttributes([.font : font], range: range)
                }
                
                bodyAttributes
                    .filter { $0.type == .mention }
                    .sorted(by: { $0.offset > $1.offset })
                    .forEach { bodyAttribute in
                        let location = max(0, min(text.length - 1, bodyAttribute.offset))
                        let length = max(0, min(text.length - location, bodyAttribute.length))
                        let range = NSRange(location: location, length: length)
                        if
                            let userId = bodyAttribute.metadata,
                            let user = message.mentionedUsers?.first(where: { $0.id == userId }) {
                            var attributes = text.attributes(at: range.location, effectiveRange: nil)
                            attributes[.font] = mentionFont
                            attributes[.foregroundColor] = mentionColor
                            attributes[.mention] = userId
                            let mention = NSAttributedString(string: SceytChatUIKit.shared.config.mentionTriggerPrefix + messageBodyAttributes.mentionUserNameFormatter.format(user),
                                                             attributes: attributes)
                            text.safeReplaceCharacters(in: range, with: mention)
                        }
                    }
            }
            
            if let attachment = message.attachments?.last,
               let icon = messageBodyAttributes.attachmentIconProvider.provideVisual(for: attachment) {
                
                let type = messageBodyAttributes.attachmentNameFormatter.format(attachment)
                if !type.isEmpty {
                    let attachment = NSTextAttachment()
                    attachment.bounds = CGRect(x: 0, y: (bodyFont.capHeight - icon.size.height).rounded() / 2, width: icon.size.width, height: icon.size.height)
                    attachment.image = icon
                    let attributedAttachmentMessage = NSMutableAttributedString(attachment: attachment)
                    attributedAttachmentMessage.append(NSAttributedString(
                        string: " ",
                        attributes: [.font: bodyFont]
                    ))
                    if text.isEmpty {
                        attributedAttachmentMessage.append(NSAttributedString(
                            string: type,
                            attributes: [
                                .font: bodyFont,
                                .foregroundColor: bodyColor
                            ]
                        ))
                        text.append(attributedAttachmentMessage)
                    } else {
                        text.insert(attributedAttachmentMessage, at: 0)
                    }
                }
            }
            if let lastReaction = messageBodyAttributes.lastReaction {
                let prefix = NSMutableAttributedString(
                    attributedString: NSAttributedString(string: "\(L10n.Channel.Message.lastReaction(lastReaction.key)) ”",
                                                         attributes: [
                                                            .font: bodyFont,
                                                            .foregroundColor: bodyColor
                                                         ]))
                let suffix = NSMutableAttributedString(
                    attributedString: NSAttributedString(string: "”",
                                                         attributes: [
                                                            .font: bodyFont,
                                                            .foregroundColor: bodyColor
                                                         ]))
                text.insert(prefix, at: 0)
                text.append(suffix)
            }
            return text
        }
    }
}
