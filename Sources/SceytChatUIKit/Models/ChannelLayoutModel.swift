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
        guard let message = lastMessage else { return NSAttributedString() }
        
        let attributedString: NSAttributedString
        switch message.state {
        case .deleted:
            attributedString = appearance.lastMessageBodyFormatter.format(
                .init(
                    message: message,
                    lastReaction: hasReaction ? lastReaction: nil,
                    deletedStateText: appearance.deletedStateText,
                    bodyLabelAppearance: appearance.lastMessageLabelAppearance,
                    linkLabelAppearance: appearance.linkLabelAppearance,
                    mentionLabelAppearance: appearance.mentionLabelAppearance,
                    deletedLabelAppearance: appearance.deletedLabelAppearance,
                    attachmentNameFormatter: appearance.attachmentNameFormatter,
                    attachmentIconProvider: appearance.attachmentIconProvider,
                    mentionUserNameFormatter: appearance.mentionUserNameFormatter
                )
            )
        default:
            let text = appearance.lastMessageBodyFormatter.format(
                .init(
                    message: message,
                    lastReaction: hasReaction ? lastReaction: nil,
                    deletedStateText: appearance.deletedStateText,
                    bodyLabelAppearance: appearance.lastMessageLabelAppearance,
                    linkLabelAppearance: appearance.linkLabelAppearance,
                    mentionLabelAppearance: appearance.mentionLabelAppearance,
                    deletedLabelAppearance: appearance.deletedLabelAppearance,
                    attachmentNameFormatter: appearance.attachmentNameFormatter,
                    attachmentIconProvider: appearance.attachmentIconProvider,
                    mentionUserNameFormatter: appearance.mentionUserNameFormatter
                )
            )
            let sender: String = hasReaction ? appearance.reactedUserNameFormatter.format(channel) : appearance.lastMessageSenderNameFormatter.format(channel)
            if !sender.isEmpty {
                let ms = NSMutableAttributedString(
                    string: sender,
                    attributes: [
                        .font: appearance.lastMessageSenderNameLabelAppearance.font,
                        .foregroundColor: appearance.lastMessageSenderNameLabelAppearance.foregroundColor
                    ]
                )
                ms.append(text)
                attributedString = ms
            } else {
                attributedString = text
            }
        }
        return attributedString
    }
    
    open func createDraftMessageIfNeeded() -> NSAttributedString? {
        guard let draft = channel.draftMessage,
              draft.length > 0
        else { return nil }
        
        return appearance.draftMessageBodyFormatter.format(
            .init(
                draftMessage: draft,
                draftPrefixLabelAppearance: appearance.draftPrefixLabelAppearance,
                draftStateText: appearance.draftStateText,
                lastMessageLabelAppearance: appearance.lastMessageLabelAppearance
            )
        )
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
        appearance.avatarAppearance
        appearance.channelAvatarRenderer.render(channel, with: appearance.avatarAppearance) { [weak self] image in
            self?.avatar = image
        }
    }
}
