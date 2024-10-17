//
//  ChannelLayoutModel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat
import Combine

open class ChannelLayoutModel {
    
    public private(set) var appearance: ChannelListViewController.ChannelCell.Appearance
    
    public private(set) var channel: ChatChannel
    
    public private(set) var attributedView: NSAttributedString!
    
    @Published public private(set) var avatar: UIImage?
    
    public  var attachmentType: String? {
        lastMessage?.attachments?.last?.type
    }
    
    public var hasReaction: Bool {
        if let reaction = channel.lastReaction,
           let lastMessage = channel.lastMessage,
           reaction.createdAt > lastMessage.createdAt,
           reaction.message != nil {
            return true
        }
        return false
    }
    
    public var lastMessage: ChatMessage? {
        if hasReaction {
            return channel.lastReaction?.message
        }
        return channel.lastMessage
    }
    
    public var lastReaction: ChatMessage.Reaction? {
        channel.lastReaction
    }
    
    public var formattedSubject: String!
    
    public var formattedDate: String!
    
    public var formattedUnreadCount: String!
    
    required public init(channel: ChatChannel, appearance: ChannelListViewController.ChannelCell.Appearance) {
        self.channel = channel
        self.appearance = appearance
        formattedSubject = createFormattedSubject()
        formattedDate = createFormattedDate()
        formattedUnreadCount = createFormattedUnreadCount()
        if let message = createDraftMessageIfNeeded() {
            attributedView = message
        } else {
            attributedView = attributedBody()
        }
        
        loadAvatar()
    }
    
    open func update(
        channel: ChatChannel,
        force: Bool = false) -> Bool {
            let selfChannel = self.channel
            
            func updateChannel() {
                if let message = createDraftMessageIfNeeded() {
                    attributedView = message
                } else {
                    attributedView = attributedBody()
                }
            }
            
            if force {
                self.channel = channel
                updateChannel()
                return true
            }
            
            var update =
            channel.draftMessage != selfChannel.draftMessage ||
            channel.lastMessage?.id != selfChannel.lastMessage?.id ||
            channel.lastMessage?.tid != selfChannel.lastMessage?.tid ||
            channel.lastMessage?.state != selfChannel.lastMessage?.state ||
            channel.lastMessage?.updatedAt != selfChannel.lastMessage?.updatedAt ||
            channel.lastReaction?.id != selfChannel.lastReaction?.id ||
            channel.lastReaction?.message?.id != selfChannel.lastReaction?.message?.id ||
            channel.lastMessage?.deliveryStatus != selfChannel.lastMessage?.deliveryStatus
            
            if !update, let p1 = channel.peer, let p2 = selfChannel.peer, p1 !~= p2 {
                update = true
            }
            
            self.channel = channel
            
            if channel.imageUrl != selfChannel.imageUrl {
                loadAvatar()
            }
            formattedSubject = createFormattedSubject()
            formattedDate = createFormattedDate()
            formattedUnreadCount = createFormattedUnreadCount()
            
            if update {
                updateChannel()
            }
            return update
        }
    
    open func updateMemberWithUser(_ user: ChatUser) {
        if let members = channel.members,
           let index = members.firstIndex(where: {$0.id == user.id}) {
            let currentUser = members[index]
            let shouldUpdateAvatar = currentUser.avatarUrl != user.avatarUrl
            currentUser.firstName = user.firstName
            currentUser.lastName = user.lastName
            currentUser.username = user.username
            currentUser.avatarUrl = user.avatarUrl
            currentUser.metadataDict = user.metadataDict
            currentUser.presence = user.presence
            currentUser.state = user.state
            formattedSubject = createFormattedSubject()
            if shouldUpdateAvatar {
                loadAvatar()
            }
        }
    }
    
    open func attributedBody() -> NSAttributedString {
        let deletedMessageFont = appearance.deletedLabelAppearance.font
        let deletedMessageColor = appearance.deletedLabelAppearance.foregroundColor
        let senderLabelFont = appearance.lastMessageSenderNameLabelAppearance.font
        let senderLabelTextColor = appearance.lastMessageSenderNameLabelAppearance.foregroundColor
        let messageLabelFont = appearance.lastMessageLabelAppearance.font
        let messageLabelTextColor = appearance.lastMessageLabelAppearance.foregroundColor
        let mentionFont = appearance.mentionLabelAppearance.font
        let mentionColor = appearance.mentionLabelAppearance.foregroundColor
        let linkColor = appearance.linkLabelAppearance.foregroundColor
        let linkFont = appearance.linkLabelAppearance.font
        
        guard let message = lastMessage
        else {
            return NSAttributedString()
        }
        let attributedView: NSAttributedString
        switch message.state {
        case .deleted:
            attributedView = NSAttributedString(string: L10n.Message.deleted,
                                                attributes: [.font: deletedMessageFont,
                                                             .foregroundColor: deletedMessageColor])
        default:
            var content = message.body.replacingOccurrences(of: "\n", with: " ")
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let text = NSMutableAttributedString(
                attributedString: NSAttributedString(string: content,
                                                     attributes: [.font: messageLabelFont,
                                                                  .foregroundColor: messageLabelTextColor]))
            
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
            
            let mentionedUsers = message.mentionedUsers?.map { ($0.id, appearance.mentionUserNameFormatter.format($0)) }
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
                    var font = messageLabelFont
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
                            let mention = NSAttributedString(string: SceytChatUIKit.shared.config.mentionTriggerPrefix + user.displayName,
                                                             attributes: attributes)
                            text.safeReplaceCharacters(in: range, with: mention)
                        }
                    }
            }
            
            if let attachment = lastMessage?.attachments?.last {
                let type = appearance.attachmentNameFormatter.format(attachment)
                var icon = appearance.attachmentIconProvider.provideVisual(for: attachment)
             
                if let icon, !type.isEmpty {
                    let font = Fonts.regular.withSize(15)
                    let attachment = NSTextAttachment()
                    attachment.bounds = CGRect(x: 0, y: (font.capHeight - icon.size.height).rounded() / 2, width: icon.size.width, height: icon.size.height)
                    attachment.image = icon
                    let attributedAttachmentMessage = NSMutableAttributedString(attachment: attachment)
                    attributedAttachmentMessage.append(NSAttributedString(
                        string: " ",
                        attributes: [.font: font]
                    ))
                    if text.isEmpty {
                        attributedAttachmentMessage.append(NSAttributedString(
                            string: type,
                            attributes: [
                                .font: font,
                                .foregroundColor: messageLabelTextColor
                            ]
                        ))
                        text.append(attributedAttachmentMessage)
                    } else {
                        text.insert(attributedAttachmentMessage, at: 0)
                        
                    }
                }
            }
            if hasReaction {
                let prefix = NSMutableAttributedString(
                    attributedString: NSAttributedString(string: "\(L10n.Channel.Message.lastReaction(lastReaction?.key ?? "")) ”",
                                                         attributes: [.font: messageLabelFont,
                                                                      .foregroundColor: messageLabelTextColor]))
                let suffix = NSMutableAttributedString(
                    attributedString: NSAttributedString(string: "”",
                                                         attributes: [.font: messageLabelFont,
                                                                      .foregroundColor: messageLabelTextColor]))
                text.insert(prefix, at: 0)
                text.append(suffix)
            }
            var hasReaction: Bool {
                if let reaction = channel.lastReaction,
                   let lastMessage = channel.lastMessage,
                   reaction.createdAt > lastMessage.createdAt,
                   reaction.message != nil {
                    return true
                }
                return false
            }
            var sender: String = hasReaction ? appearance.lastMessageSenderNameFormatter.format(channel) : appearance.reactedUserNameFormatter.format(channel)
            if !sender.isEmpty {
                let ms = NSMutableAttributedString(string: sender,
                                                   attributes: [.font: senderLabelFont,
                                                                .foregroundColor: senderLabelTextColor])
                ms.append(text)
                attributedView = ms
            } else {
                attributedView = text
            }
        }
        return attributedView
    }
    
    open func createDraftMessageIfNeeded() -> NSAttributedString? {
        guard let draft = channel.draftMessage,
              draft.length > 0
        else { return nil }
        
        let text = NSMutableAttributedString()
        let title = L10n.Channel.Message.draft
        let draftString = NSMutableAttributedString(string: "\(title)\n")
        draftString.addAttributes(
            [.foregroundColor: appearance.draftPrefixLabelAppearance.foregroundColor,
             .font: appearance.draftPrefixLabelAppearance.font],
            range: NSMakeRange(0, title.count))
        text.append(draftString)
        
        let contentString = NSMutableAttributedString(attributedString: draft)
        contentString.addAttributes(
            [.foregroundColor: appearance.lastMessageLabelAppearance.foregroundColor,
             .font: appearance.lastMessageLabelAppearance.font],
            range: NSMakeRange(0, draft.length))
        text.append(contentString)
        return text
    }
    
    open func createFormattedSubject() -> String {
        appearance.channelNameFormatter.format(channel)
    }
    
    open func createFormattedDate() -> String {
        if hasReaction,
           let message = channel.lastReaction?.message {
            return appearance.channelDateFormatter.format(message.updatedAt ?? message.createdAt )
        }
        if let message = channel.lastMessage {
            return appearance.channelDateFormatter.format(message.updatedAt ?? message.createdAt )
        }
        return appearance.channelDateFormatter.format(channel.updatedAt ?? channel.createdAt )
    }
    
    open func createFormattedUnreadCount() -> String {
        appearance.unreadCountFormatter.format(channel.newMessageCount)
    }
    
    open func loadAvatar() {
        _ = switch appearance.channelDefaultAvatarProvider.provideVisual(for: channel) {
        case .image(let image):
            _ = Components.avatarBuilder.loadAvatar(for: channel,
                                                    defaultImage: image) {[weak self] image in
                self?.avatar = image
            }
        case .initialsAppearance(let initialsAppearance):
            _ = Components.avatarBuilder.loadAvatar(for: channel,
                                                    appearance: initialsAppearance) {[weak self] image in
                self?.avatar = image
            }
        }
    }
}
