//
//  MessageBodyFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 31.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class MessageBodyFormatter: MessageBodyContentFormatting {
    
    public init() {}
    
    open func format(_ messageBodyAttributes: MessageBodyContentFormatterAttributes) -> (NSAttributedString, [MessageLayoutModel.ContentItem]) {
        let message = messageBodyAttributes.message
        
        switch message.state {
        case .deleted:
            let text = NSAttributedString(string: messageBodyAttributes.deletedStateText,
                                          attributes: [
                                            .font: messageBodyAttributes.deletedMessageLabelAppearance.font,
                                            .foregroundColor: messageBodyAttributes.deletedMessageLabelAppearance.foregroundColor
                                          ])
            return (text, [])
            
        default:
            let userSendMessage = messageBodyAttributes.userSendMessage
            let bodyFont = messageBodyAttributes.bodyLabelAppearance.font
            let bodyColor = messageBodyAttributes.bodyLabelAppearance.foregroundColor
            let linkFont = messageBodyAttributes.linkLabelAppearance.font
            let linkColor = messageBodyAttributes.linkLabelAppearance.foregroundColor
            let mentionFont = messageBodyAttributes.mentionLabelAppearance.font
            let mentionColor = messageBodyAttributes.mentionLabelAppearance.foregroundColor
            
            var content = message.body
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if content.isEmpty { return (NSAttributedString(), []) }
            
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(
                    string: content,
                    attributes: [
                        .font: bodyFont,
                        .foregroundColor: bodyColor
                    ]
                )
            )
            
            var items = [MessageLayoutModel.ContentItem]()
            var replacedContent = content
            
            let mentionedUsers = message.mentionedUsers != nil ?
            message.mentionedUsers!.map { ($0.id, messageBodyAttributes.mentionUserNameFormatter.format($0)) } :
            userSendMessage?.mentionUsers
            if let mentionedUsers = mentionedUsers, mentionedUsers.count > 0,
               let metadata = message.metadata?.data(using: .utf8),
               let ranges = try? JSONDecoder().decode([MentionUserPos].self, from: metadata) {
                var lengths = 0
                for pos in ranges.reversed() {
                    if let user = mentionedUsers.last(where: { $0.0 == pos.id }), pos.loc >= 0 {
                        let attributes: [NSAttributedString.Key : Any] = [
                            .font: mentionFont,
                            .foregroundColor: mentionColor,
                            .mention: pos.id
                        ]
                        let mention = NSAttributedString(string: SceytChatUIKit.shared.config.mentionTriggerPrefix + user.displayName,
                                                         attributes: attributes)
                        guard text.length >= pos.loc + pos.len else {
                            logger.error("Something wrong❗️❗️, body: \(text.string) mention: \(mention.string) pos: \(pos.loc), \(pos.len) user: \(pos.id)")
                            continue
                        }
                        let range = NSRange(location: pos.loc, length: pos.len)
                        text.safeReplaceCharacters(in: range, with: mention)
                        if let rangeEx = Range(range, in: replacedContent) {
                            replacedContent = replacedContent.replacingCharacters(in: rangeEx, with: mention.string)
                        }
                        lengths += mention.length
                        items.append(.mention(.init(location: pos.loc, length: mention.length), pos.id))
                    }
                }
            }
            if let bodyAttributes = message.bodyAttributes {
                bodyAttributes.reduce([NSRange: [ChatMessage.BodyAttribute]]()) { partialResult, bodyAttribute in
                    let location = max(0, min(text.length - 1, bodyAttribute.offset))
                    let length = max(0, min(text.length - location, bodyAttribute.length))
                    let range = NSRange(location: location, length: length)
                    var array = partialResult[range] ?? []
                    array.append(bodyAttribute)
                    var partialResult = partialResult
                    partialResult[range] = array
                    return partialResult
                }
                .forEach { range, value in
                    var font = bodyFont
                    if value.contains(where: { $0.type == .monospace }) {
                        font = font.toMonospace
                    }
                    if value.contains(where: { $0.type == .bold }) {
                        font = font.toBold
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
                            attributes[.foregroundColor] = mentionColor
                            attributes[.font] = mentionFont
                            attributes[.mention] = userId
                            let mention = NSAttributedString(string: SceytChatUIKit.shared.config.mentionTriggerPrefix + messageBodyAttributes.mentionUserNameFormatter.format(user),
                                                             attributes: attributes)
                            text.safeReplaceCharacters(in: range, with: mention)
                            if let rangeEx = Range(range, in: replacedContent) {
                                replacedContent = replacedContent.replacingCharacters(in: rangeEx, with: mention.string)
                            }
                            items.append(.mention(.init(location: bodyAttribute.offset, length: mention.length), userId))
                        }
                    }
            }
            
            
            let matches = DataDetector.matches(text: replacedContent)
            for match in matches {
                let linkAttributes: [NSAttributedString.Key : Any] = [
                    NSAttributedString.Key.foregroundColor: linkColor,
                    NSAttributedString.Key.underlineColor: linkColor,
                    NSAttributedString.Key.font: linkFont,
                    NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                text.addAttributes(linkAttributes, range: match.range)
                items.append(.link(match.range, match.url))
            }
            
            return (text, items)
        }
    }
}
