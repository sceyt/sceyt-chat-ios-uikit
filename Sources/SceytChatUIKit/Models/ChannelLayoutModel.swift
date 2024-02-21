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
    
    public static var appearance = ChannelCell.appearance
    
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
    
    public var formatedSubject: String!
    
    public var formatedDate: String!
    
    public var formatedUnreadCount: String!
    
    required public init(channel: ChatChannel) {
        self.channel = channel
        formatedSubject = createFormattedSubject()
        formatedDate = createFormattedDate()
        formatedUnreadCount = createFormattedUnreadCount()
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
            formatedSubject = createFormattedSubject()
            formatedDate = createFormattedDate()
            formatedUnreadCount = createFormattedUnreadCount()
            
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
            currentUser.avatarUrl = user.avatarUrl
            currentUser.metadata = user.metadata
            currentUser.presence = user.presence
            currentUser.state = user.state
            formatedSubject = Formatters.channelDisplayName.format(channel)
            if shouldUpdateAvatar {
                loadAvatar()
            }
        }
    }
    
    open func attributedBody() -> NSAttributedString {
        let deletedMessageFont = Self.appearance.deletedMessageFont ?? Appearance.Fonts.regular.with(traits: .traitItalic).withSize(15)
        let deletedMessageColor = Self.appearance.deletedMessageColor ?? Appearance.Colors.textGray
        let senderLabelFont = Self.appearance.senderLabelFont ?? Appearance.Fonts.regular.withSize(15)
        let senderLabelTextColor = Self.appearance.senderLabelTextColor ?? Appearance.Colors.textBlack
        let messageLabelFont = Self.appearance.messageLabelFont ?? Appearance.Fonts.regular.withSize(15)
        let messageLabelTextColor = Self.appearance.messageLabelTextColor ?? Appearance.Colors.textGray
        let mentionFont = Self.appearance.mentionFont ?? Appearance.Fonts.bold.withSize(15)
        let mentionColor = Self.appearance.mentionColor ?? Appearance.Colors.textGray
        let linkColor = Self.appearance.linkColor ?? Appearance.Colors.textGray
        let linkFont = Self.appearance.linkFont ?? Appearance.Fonts.regular.withSize(15)
        
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
            
            let mentionedUsers = message.mentionedUsers?.map { ($0.id, Formatters.userDisplayName.format($0)) }
            if let mentionedUsers = mentionedUsers, mentionedUsers.count > 0,
               let metadata = message.metadata?.data(using: .utf8),
               let ranges = try? JSONDecoder().decode([MentionUserPos].self, from: metadata) {
                var lengths = 0
                for pos in ranges.reversed() {
                    if let user = mentionedUsers.last(where: { $0.0 == pos.id }), pos.loc >= 0 {
                        let attributes: [NSAttributedString.Key : Any] = [.font: mentionFont,
                                                                          .foregroundColor: mentionColor,
                                                                          .mention: pos.id]
                        let mention = NSAttributedString(string: Config.mentionSymbol + user.1,
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
                        font = Formatters.font.toMonospace(font)
                    }
                    if value.contains(where: { $0.type == .bold }) {
                        font = Formatters.font.toBold(font)
                    }
                    if value.contains(where: { $0.type == .italic }) {
                        font = Formatters.font.toItalic(font)
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
                            let mention = NSAttributedString(string: Config.mentionSymbol + user.displayName,
                                                             attributes: attributes)
                            text.safeReplaceCharacters(in: range, with: mention)
                        }
                    }
            }
            
            if let attachmentType {
                var icon: UIImage?
                var type: String?
                switch attachmentType {
                case "file":
                    icon = Images.attachmentFile
                    type = L10n.Attachment.file
                case "image":
                    icon = Images.attachmentImage
                    type = L10n.Attachment.image
                case "video":
                    icon = Images.attachmentVideo
                    type = L10n.Attachment.video
                case "voice":
                    icon = Images.attachmentVoice
                    type = L10n.Attachment.voice
                default:
                    break
                }
                if let icon, let type {
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
                            attributes: [.font: font]
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
            
            var sender: String?
            let user: ChatUser?
            if hasReaction {
                user = lastReaction?.user
            } else {
                user = lastMessage?.user
            }
            if let user {
                if lastMessage?.state == .deleted {
                    // don't display sender
                } else if (user.id == me) || (user.id.isEmpty && lastMessage?.incoming == false) {
                    sender = "\(L10n.User.current): "
                } else if channel.isGroup {
                    sender = "\(Formatters.userDisplayName.short(user)): "
                }
            }
            if let s = sender {
                let ms = NSMutableAttributedString(string: s,
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
            [.foregroundColor: Self.appearance.draftMessageTitleColor as Any,
             .font: Self.appearance.draftMessageTitleFont as Any],
            range: NSMakeRange(0, title.count))
        text.append(draftString)
        
        let contentString = NSMutableAttributedString(attributedString: draft)
        contentString.addAttributes(
            [.foregroundColor: Self.appearance.draftMessageContentColor as Any,
             .font: Self.appearance.draftMessageContentFont as Any ],
            range: NSMakeRange(0, draft.length))
        text.append(contentString)
        return text
    }
    
    open func createFormattedSubject() -> String {
        Formatters.channelDisplayName.format(channel)
    }
    
    open func createFormattedDate() -> String {
        if hasReaction,
           let message = channel.lastReaction?.message {
            return Formatters.channelTimestamp.format(message.updatedAt ?? message.createdAt )
        }
        if let message = channel.lastMessage {
            return Formatters.channelTimestamp.format(message.updatedAt ?? message.createdAt )
        }
        return Formatters.channelTimestamp.format(channel.updatedAt ?? channel.createdAt )
    }
    
    open func createFormattedUnreadCount() -> String {
        Formatters
            .channelUnreadMessageCount
            .format(channel.newMessageCount)
    }
    
    open func loadAvatar() {
        _ = Components.avatarBuilder.loadAvatar(for: channel) {[weak self] image in
            self?.avatar = image
        }
    }
    
}
