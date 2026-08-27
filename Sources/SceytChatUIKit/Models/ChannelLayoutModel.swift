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

    /// The content size category the cached `attributedView` was last built for.
    /// Used to skip redundant rebuilds; `nil` until the first rebuild after a
    /// Dynamic Type change.
    private var attributedViewContentSizeCategory: UIContentSizeCategory?

    /// The trait collection the preview fonts should be scaled for, set after a
    /// Dynamic Type change. `nil` means "use the configured appearance as-is"
    /// (launch behavior), which keeps `init` free of any trait/main-thread
    /// dependency.
    private var currentTraitCollection: UITraitCollection?

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

    public var hasDraftMessage: Bool {
        // A draft need not have any text: an image picked with nothing typed previews as
        // "Draft: Image", and a bare reply target as "Draft: Reply". Both still count.
        if channel.draftAttachmentType != nil || channel.draftActionType != nil { return true }
        guard let draft = channel.draftMessage else { return false }
        return draft.length > 0
    }

    public var shouldShowDeliveryTick: Bool {
        guard !hasDraftMessage, let message = lastMessage else { return false }
        return message.state != .deleted && !message.isSystemMessage
    }

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
            channel.draftAttachmentType != selfChannel.draftAttachmentType ||
            channel.draftActionType != selfChannel.draftActionType ||
            channel.lastMessage?.id != selfChannel.lastMessage?.id ||
            channel.lastMessage?.tid != selfChannel.lastMessage?.tid ||
            channel.lastMessage?.state != selfChannel.lastMessage?.state ||
            channel.lastMessage?.updatedAt != selfChannel.lastMessage?.updatedAt ||
            channel.lastReaction?.id != selfChannel.lastReaction?.id ||
            channel.lastReaction?.message?.id != selfChannel.lastReaction?.message?.id ||
            channel.lastMessage?.deliveryStatus != selfChannel.lastMessage?.deliveryStatus ||
            channel.lastMessage?.metadata != selfChannel.lastMessage?.metadata
            
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

    /// Rebuilds every formatter-derived field (subject, date, unread count and
    /// the last-message preview) from the current `channel`, keeping the
    /// already-rendered `avatar` untouched.
    ///
    /// Use this when something *outside* the channel changed the formatter
    /// output — e.g. the device contact book synced and `channelNameFormatter`
    /// now resolves a different display name. Discarding the whole model for
    /// that (the old `invalidateLayoutModels` behavior) also discarded the
    /// avatar, so every visible cell flashed an empty avatar until the async
    /// re-render completed.
    open func reloadFormattedContent() {
        formattedSubject = createFormattedSubject()
        formattedDate = createFormattedDate()
        formattedUnreadCount = createFormattedUnreadCount()
        attributedView = createDraftMessageIfNeeded() ?? attributedBody()
    }

    /// Rebuilds the cached `attributedView` with fonts scaled for the given
    /// trait collection's content size category.
    ///
    /// `attributedView` is otherwise built once with fonts frozen at the launch
    /// Dynamic Type category. A `UILabel` re-scales an attributed string's
    /// embedded fonts only via the live content-size-change notification, and
    /// only while the label is on screen — so a reused cell bound *after* a
    /// Large Text change would render the preview at the old size. Calling this
    /// on a category change keeps the cache (and therefore every re-bound cell)
    /// correctly sized; subsequent `update(channel:)` rebuilds also stay scaled
    /// because the trait collection is remembered.
    open func reloadAttributedView(compatibleWith traitCollection: UITraitCollection?) {
        let category = (traitCollection ?? .current).preferredContentSizeCategory
        guard category != attributedViewContentSizeCategory else { return }
        attributedViewContentSizeCategory = category
        currentTraitCollection = traitCollection

        if let message = createDraftMessageIfNeeded() {
            attributedView = message
        } else {
            attributedView = attributedBody()
        }
    }

    /// The configured appearance, but with the preview label fonts re-derived
    /// for `currentTraitCollection` once a Dynamic Type change has occurred.
    ///
    /// Built as a value-isolated copy (`init(reference:)` makes fresh backing
    /// storage), so it never mutates the shared/static appearance these models
    /// are created from. Before any change it returns the configured appearance
    /// unchanged, preserving launch behavior.
    open func effectiveAppearance() -> ChannelListViewController.ChannelCell.Appearance {
        guard let traitCollection = currentTraitCollection else { return appearance }
        return .init(
            reference: appearance,
            lastMessageLabelAppearance: appearance.lastMessageLabelAppearance.rescaledFont(compatibleWith: traitCollection),
            lastMessageSenderNameLabelAppearance: appearance.lastMessageSenderNameLabelAppearance.rescaledFont(compatibleWith: traitCollection),
            deletedLabelAppearance: appearance.deletedLabelAppearance.rescaledFont(compatibleWith: traitCollection),
            draftPrefixLabelAppearance: appearance.draftPrefixLabelAppearance.rescaledFont(compatibleWith: traitCollection),
            mentionLabelAppearance: appearance.mentionLabelAppearance.rescaledFont(compatibleWith: traitCollection),
            linkLabelAppearance: appearance.linkLabelAppearance.rescaledFont(compatibleWith: traitCollection),
            phoneNumberLabelAppearance: appearance.phoneNumberLabelAppearance.rescaledFont(compatibleWith: traitCollection)
        )
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
        // Use fonts scaled for the current Dynamic Type category (no-op before
        // any change). See `effectiveAppearance()`.
        let appearance = effectiveAppearance()

        // Handle system messages
        if message.isSystemMessage {
            let formattedText = SceytChatUIKit.shared.formatters.systemMessageBodyFormatter.format(message)
            return NSAttributedString(
                string: formattedText,
                attributes: [
                    .font: appearance.lastMessageLabelAppearance.font,
                    .foregroundColor: appearance.lastMessageLabelAppearance.foregroundColor
                ]
            )
        }

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
                    phoneNumberLabelAppearance: appearance.phoneNumberLabelAppearance,
                    mentionLabelAppearance: appearance.mentionLabelAppearance,
                    deletedLabelAppearance: appearance.deletedLabelAppearance,
                    attachmentNameFormatter: appearance.attachmentNameFormatter,
                    attachmentIconProvider: appearance.attachmentIconProvider,
                    messageTypeIconProvider: appearance.messageTypeIconProvider,
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
                    phoneNumberLabelAppearance: appearance.phoneNumberLabelAppearance,
                    mentionLabelAppearance: appearance.mentionLabelAppearance,
                    deletedLabelAppearance: appearance.deletedLabelAppearance,
                    attachmentNameFormatter: appearance.attachmentNameFormatter,
                    attachmentIconProvider: appearance.attachmentIconProvider,
                    messageTypeIconProvider: appearance.messageTypeIconProvider,
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
        let draft = channel.draftMessage ?? NSAttributedString()
        let attachment = draftAttachmentForPreview()
        let appearance = effectiveAppearance()
        let actionText: String? = switch channel.draftActionType {
        case "reply": appearance.draftReplyStateText
        case "edit": appearance.draftEditStateText
        default: nil
        }
        guard draft.length > 0 || attachment != nil || actionText != nil else { return nil }

        return appearance.draftMessageBodyFormatter.format(
            .init(
                draftMessage: draft,
                draftPrefixLabelAppearance: appearance.draftPrefixLabelAppearance,
                draftStateText: appearance.draftStateText,
                lastMessageLabelAppearance: appearance.lastMessageLabelAppearance,
                draftAttachment: attachment,
                attachmentNameFormatter: appearance.attachmentNameFormatter,
                attachmentIconProvider: appearance.attachmentIconProvider,
                draftActionText: actionText
            )
        )
    }

    /// A stand-in attachment carrying only the persisted type, which is all the name formatter and
    /// icon provider read. The channel row stores just the type so the list never has to fault the
    /// draft's own attachment rows.
    private func draftAttachmentForPreview() -> ChatMessage.Attachment? {
        guard let type = channel.draftAttachmentType else { return nil }
        return .init(
            id: 0,
            tid: 0,
            messageId: 0,
            userId: "",
            url: nil,
            filePath: nil,
            type: type,
            uploadedFileSize: 0,
            createdAt: Date()
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
        appearance.channelAvatarRenderer.render(channel, with: appearance.avatarAppearance) { [weak self] image in
            self?.avatar = image
        }
    }
}
