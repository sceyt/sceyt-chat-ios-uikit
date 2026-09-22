//
//  ChannelLastMessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 31.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelLastMessageBodyFormatter: LastMessageBodyFormatting {
    
    public init() {}
    
    open func format(_ messageBodyAttributes: LastMessageBodyFormatterAttributes) -> NSAttributedString {
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
            // Check if message is unsupported
            if MessageLayoutModel.isMessageUnsupported(message) {
                return SceytChatUIKit.shared.formatters.unsupportedMessageShortFormatter.format(message)
            }

            let bodyFont = messageBodyAttributes.bodyLabelAppearance.font
            let bodyColor = messageBodyAttributes.bodyLabelAppearance.foregroundColor
            let mentionFont = messageBodyAttributes.mentionLabelAppearance.font
            let mentionColor = messageBodyAttributes.mentionLabelAppearance.foregroundColor
            let linkColor = messageBodyAttributes.linkLabelAppearance.foregroundColor
            let linkFont = messageBodyAttributes.linkLabelAppearance.font
            let phoneNumberColor = messageBodyAttributes.linkLabelAppearance.foregroundColor
            let phoneNumberFont = messageBodyAttributes.linkLabelAppearance.font
            
            var content = message.body.replacingOccurrences(of: "\n", with: " ")
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var text = NSMutableAttributedString(
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
            
            let phoneNumberMatches = DataDetector.getPhoneNumbers(text: content)
            for phoneNumberMatch in phoneNumberMatches {
                let linkAttributes: [NSAttributedString.Key : Any] = [
                    .font: phoneNumberFont,
                    .foregroundColor: phoneNumberColor,
                    .underlineColor: phoneNumberColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                text.addAttributes(linkAttributes, range: phoneNumberMatch.range)
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
            
            // Use messageTypeIconProvider first to handle polls and other message types
            if let icon = messageBodyAttributes.messageTypeIconProvider.provideVisual(for: message) {
                // Apply color to template images (like poll icon)
                let finalIcon: UIImage
                if icon.renderingMode == .alwaysTemplate {
                    // Use specific poll icon color for polls, otherwise use body color
                    let tintColor = message.poll != nil ? DefaultColors.iconTertiary : bodyColor
                    finalIcon = icon.withTintColor(tintColor, renderingMode: .alwaysOriginal)
                } else {
                    finalIcon = icon
                }

                let baseIconFont = messageBodyAttributes.bodyLabelAppearance.baseFont
                let iconScale = baseIconFont.pointSize > 0 ? bodyFont.pointSize / baseIconFont.pointSize : 1
                let iconSide = (16 * iconScale).rounded(.up)
                let iconSize = CGSize(width: iconSide, height: iconSide)
                let sizedIcon = UIGraphicsImageRenderer(size: iconSize).image { _ in
                    finalIcon.draw(in: CGRect(origin: .zero, size: iconSize))
                }

                let attachment = NSTextAttachment()
                attachment.bounds = CGRect(x: 0, y: (bodyFont.capHeight - sizedIcon.size.height).rounded() / 2, width: sizedIcon.size.width, height: sizedIcon.size.height)
                attachment.image = sizedIcon
                let attributedAttachmentMessage = NSMutableAttributedString(attachment: attachment)
                attributedAttachmentMessage.append(NSAttributedString(
                    string: " ",
                    attributes: [.font: bodyFont]
                ))

                // Get the attachment type name
                var attachmentTypeName = ""
                if let attachment = message.attachments?.first {
                    switch attachment.type {
                    case "image":
                        attachmentTypeName = L10n.Attachment.image
                    case "video":
                        attachmentTypeName = L10n.Attachment.video
                    case "file":
                        attachmentTypeName = L10n.Attachment.file
                    case "voice":
                        attachmentTypeName = L10n.Attachment.voice
                    default:
                        attachmentTypeName = ""
                    }
                }
                
                // For view_once messages, replace text with attachment type name
                if message.isViewOnceMessage {
                    text = NSMutableAttributedString(
                        string: attachmentTypeName,
                        attributes: [
                            .font: bodyFont,
                            .foregroundColor: bodyColor
                        ]
                    )
                    text.insert(attributedAttachmentMessage, at: 0)
                } else {
                    // If there's text, insert the icon at the beginning
                    if !text.isEmpty {
                        text.insert(attributedAttachmentMessage, at: 0)
                    } else {
                        // For attachment-only messages, show icon + attachment name
                        if !attachmentTypeName.isEmpty {
                            attributedAttachmentMessage.append(NSAttributedString(
                                string: attachmentTypeName,
                                attributes: [
                                    .font: bodyFont,
                                    .foregroundColor: bodyColor
                                ]
                            ))
                        }
                        text.append(attributedAttachmentMessage)
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
