//
//  ChannelListViewController+ChannelCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension ChannelListViewController.ChannelCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .clear,
        pinnedChannelBackgroundColor: .background,
        
        // Label Appearances
        subjectLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        lastMessageLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(15)
        ),
        unreadCountLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.semiBold.withSize(14),
            backgroundColor: .accent
        ),
        unreadCountMutedStateLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.semiBold.withSize(14),
            backgroundColor: .surface3
        ),
        separatorColor: .border,
        dateLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(14)
        ),
        lastMessageSenderNameLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(15)
        ),
        deletedLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.with(traits: .traitItalic).withSize(15)
        ),
        deletedStateText: L10n.Message.deleted,
        draftPrefixLabelAppearance: LabelAppearance(
            foregroundColor: DefaultColors.defaultRed,
            font: Fonts.regular.withSize(15)
        ),
        draftStateText: L10n.Channel.Message.draft,
        typingLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.with(traits: .traitItalic).withSize(15)
        ),
        mentionLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.bold.withSize(15),
            backgroundColor: .surface3
        ),
        unreadMentionLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.bold.withSize(15),
            backgroundColor: .accent
        ),
        unreadMentionMutedStateLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.bold.withSize(15),
            backgroundColor: .surface3
        ),
        linkLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(15)
        ),
        
        // Icons
        mutedIcon: .mute,
        pinIcon: .channelPin,
        messageDeliveryStatusIcons: MessageDeliveryStatusIcons(),
        
        // Formatters and Providers
        channelNameFormatter: SceytChatUIKit.shared.formatters.channelNameFormatter,
        channelDateFormatter: SceytChatUIKit.shared.formatters.channelDateFormatter,
        unreadCountFormatter: SceytChatUIKit.shared.formatters.unreadCountFormatter,
        typingUserNameFormatter: SceytChatUIKit.shared.formatters.typingUserNameFormatter,
        mentionUserNameFormatter: SceytChatUIKit.shared.formatters.mentionUserNameFormatter,
        attachmentNameFormatter: SceytChatUIKit.shared.formatters.attachmentNameFormatter,
        lastMessageSenderNameFormatter: SceytChatUIKit.shared.formatters.channelLastMessageSenderNameFormatter,
        reactedUserNameFormatter: SceytChatUIKit.shared.formatters.reactedUserNameFormatter,
        attachmentIconProvider: SceytChatUIKit.shared.visualProviders.channelListAttachmentIconProvider,
        channelAvatarRenderer: SceytChatUIKit.shared.avatarRenderers.channelAvatarRenderer,
        avatarAppearance: AvatarAppearance.standard,
        presenceStateIconProvider: SceytChatUIKit.shared.visualProviders.presenceStateIconProvider,
        lastMessageBodyFormatter: SceytChatUIKit.shared.formatters.channelLastMessageBodyFormatter,
        draftMessageBodyFormatter: SceytChatUIKit.shared.formatters.draftMessageBodyFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var pinnedChannelBackgroundColor: UIColor
        
        // Label Appearances
        @Trackable<Appearance, LabelAppearance>
        public var subjectLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var lastMessageLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var unreadCountLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var unreadCountMutedStateLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var dateLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var lastMessageSenderNameLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var deletedLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, String>
        public var deletedStateText: String
        
        @Trackable<Appearance, LabelAppearance>
        public var draftPrefixLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, String>
        public var draftStateText: String
        
        @Trackable<Appearance, LabelAppearance>
        public var typingLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var mentionLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var unreadMentionLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var unreadMentionMutedStateLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var linkLabelAppearance: LabelAppearance
        
        // Icons
        @Trackable<Appearance, UIImage>
        public var mutedIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var pinIcon: UIImage
        
        @Trackable<Appearance, MessageDeliveryStatusIcons>
        public var messageDeliveryStatusIcons: MessageDeliveryStatusIcons
        
        // Formatters and Providers
        @Trackable<Appearance, any ChannelFormatting>
        public var channelNameFormatter: any ChannelFormatting
        
        @Trackable<Appearance, any DateFormatting>
        public var channelDateFormatter: any DateFormatting
        
        @Trackable<Appearance, any UIntFormatting>
        public var unreadCountFormatter: any UIntFormatting
        
        @Trackable<Appearance, any UserFormatting>
        public var typingUserNameFormatter: any UserFormatting
        
        @Trackable<Appearance, any UserFormatting>
        public var mentionUserNameFormatter: any UserFormatting
        
        @Trackable<Appearance, any AttachmentFormatting>
        public var attachmentNameFormatter: any AttachmentFormatting
        
        @Trackable<Appearance, any ChannelFormatting>
        public var lastMessageSenderNameFormatter: any ChannelFormatting
        
        @Trackable<Appearance, any ChannelFormatting>
        public var reactedUserNameFormatter: any ChannelFormatting
        
        @Trackable<Appearance, any AttachmentIconProviding>
        public var attachmentIconProvider: any AttachmentIconProviding
        
        @Trackable<Appearance, any ChannelAvatarRendering>
        public var channelAvatarRenderer: any ChannelAvatarRendering
        
        @Trackable<Appearance, AvatarAppearance>
        public var avatarAppearance: AvatarAppearance

        @Trackable<Appearance, any PresenceStateIconProviding>
        public var presenceStateIconProvider: any PresenceStateIconProviding
        
        @Trackable<Appearance, any LastMessageBodyFormatting>
        public var lastMessageBodyFormatter: any LastMessageBodyFormatting
        
        @Trackable<Appearance, any DraftMessageBodyFormatting>
        public var draftMessageBodyFormatter: any DraftMessageBodyFormatting
        
        // Initializer with all parameters
        public init(
            backgroundColor: UIColor,
            pinnedChannelBackgroundColor: UIColor,
            
            // Label Appearances
            subjectLabelAppearance: LabelAppearance,
            lastMessageLabelAppearance: LabelAppearance,
            unreadCountLabelAppearance: LabelAppearance,
            unreadCountMutedStateLabelAppearance: LabelAppearance,
            separatorColor: UIColor,
            dateLabelAppearance: LabelAppearance,
            lastMessageSenderNameLabelAppearance: LabelAppearance,
            deletedLabelAppearance: LabelAppearance,
            deletedStateText: String,
            draftPrefixLabelAppearance: LabelAppearance,
            draftStateText: String,
            typingLabelAppearance: LabelAppearance,
            mentionLabelAppearance: LabelAppearance,
            unreadMentionLabelAppearance: LabelAppearance,
            unreadMentionMutedStateLabelAppearance: LabelAppearance,
            linkLabelAppearance: LabelAppearance,
            
            // Icons
            mutedIcon: UIImage,
            pinIcon: UIImage,
            messageDeliveryStatusIcons: MessageDeliveryStatusIcons,
            
            // Formatters and Providers
            channelNameFormatter: any ChannelFormatting,
            channelDateFormatter: any DateFormatting,
            unreadCountFormatter: any UIntFormatting,
            typingUserNameFormatter: any UserFormatting,
            mentionUserNameFormatter: any UserFormatting,
            attachmentNameFormatter: any AttachmentFormatting,
            lastMessageSenderNameFormatter: any ChannelFormatting,
            reactedUserNameFormatter: any ChannelFormatting,
            attachmentIconProvider: any AttachmentIconProviding,
            channelAvatarRenderer: any ChannelAvatarRendering,
            avatarAppearance: AvatarAppearance,
            presenceStateIconProvider: any PresenceStateIconProviding,
            lastMessageBodyFormatter: any LastMessageBodyFormatting,
            draftMessageBodyFormatter: any DraftMessageBodyFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._pinnedChannelBackgroundColor = Trackable(value: pinnedChannelBackgroundColor)
            
            // Label Appearances
            self._subjectLabelAppearance = Trackable(value: subjectLabelAppearance)
            self._lastMessageLabelAppearance = Trackable(value: lastMessageLabelAppearance)
            self._unreadCountLabelAppearance = Trackable(value: unreadCountLabelAppearance)
            self._unreadCountMutedStateLabelAppearance = Trackable(value: unreadCountMutedStateLabelAppearance)
            self._separatorColor = Trackable(value: separatorColor)
            self._dateLabelAppearance = Trackable(value: dateLabelAppearance)
            self._lastMessageSenderNameLabelAppearance = Trackable(value: lastMessageSenderNameLabelAppearance)
            self._deletedLabelAppearance = Trackable(value: deletedLabelAppearance)
            self._deletedStateText = Trackable(value: deletedStateText)
            self._draftPrefixLabelAppearance = Trackable(value: draftPrefixLabelAppearance)
            self._draftStateText = Trackable(value: draftStateText)
            self._typingLabelAppearance = Trackable(value: typingLabelAppearance)
            self._mentionLabelAppearance = Trackable(value: mentionLabelAppearance)
            self._unreadMentionLabelAppearance = Trackable(value: unreadMentionLabelAppearance)
            self._unreadMentionMutedStateLabelAppearance = Trackable(value: unreadMentionMutedStateLabelAppearance)
            self._linkLabelAppearance = Trackable(value: linkLabelAppearance)
            
            // Icons
            self._mutedIcon = Trackable(value: mutedIcon)
            self._pinIcon = Trackable(value: pinIcon)
            self._messageDeliveryStatusIcons = Trackable(value: messageDeliveryStatusIcons)
            
            // Formatters and Providers
            self._channelNameFormatter = Trackable(value: channelNameFormatter)
            self._channelDateFormatter = Trackable(value: channelDateFormatter)
            self._unreadCountFormatter = Trackable(value: unreadCountFormatter)
            self._typingUserNameFormatter = Trackable(value: typingUserNameFormatter)
            self._mentionUserNameFormatter = Trackable(value: mentionUserNameFormatter)
            self._attachmentNameFormatter = Trackable(value: attachmentNameFormatter)
            self._lastMessageSenderNameFormatter = Trackable(value: lastMessageSenderNameFormatter)
            self._reactedUserNameFormatter = Trackable(value: reactedUserNameFormatter)
            self._attachmentIconProvider = Trackable(value: attachmentIconProvider)
            self._channelAvatarRenderer = Trackable(value: channelAvatarRenderer)
            self._avatarAppearance = Trackable(value: avatarAppearance)
            self._presenceStateIconProvider = Trackable(value: presenceStateIconProvider)
            self._lastMessageBodyFormatter = Trackable(value: lastMessageBodyFormatter)
            self._draftMessageBodyFormatter = Trackable(value: draftMessageBodyFormatter)
        }
        
        public init(
            reference: ChannelListViewController.ChannelCell.Appearance,
            backgroundColor: UIColor? = nil,
            pinnedChannelBackgroundColor: UIColor? = nil,
            
            // Label Appearances
            subjectLabelAppearance: LabelAppearance? = nil,
            lastMessageLabelAppearance: LabelAppearance? = nil,
            unreadCountLabelAppearance: LabelAppearance? = nil,
            unreadCountMutedStateLabelAppearance: LabelAppearance? = nil,
            separatorColor: UIColor? = nil,
            dateLabelAppearance: LabelAppearance? = nil,
            lastMessageSenderNameLabelAppearance: LabelAppearance? = nil,
            deletedLabelAppearance: LabelAppearance? = nil,
            deletedStateText: String? = nil,
            draftPrefixLabelAppearance: LabelAppearance? = nil,
            draftStateText: String? = nil,
            typingLabelAppearance: LabelAppearance? = nil,
            mentionLabelAppearance: LabelAppearance? = nil,
            unreadMentionLabelAppearance: LabelAppearance? = nil,
            unreadMentionMutedStateLabelAppearance: LabelAppearance? = nil,
            linkLabelAppearance: LabelAppearance? = nil,
            
            // Icons
            mutedIcon: UIImage? = nil,
            pinIcon: UIImage? = nil,
            messageDeliveryStatusIcons: MessageDeliveryStatusIcons? = nil,
            
            // Formatters and Providers
            channelNameFormatter: (any ChannelFormatting)? = nil,
            channelDateFormatter: (any DateFormatting)? = nil,
            unreadCountFormatter: (any UIntFormatting)? = nil,
            typingUserNameFormatter: (any UserFormatting)? = nil,
            mentionUserNameFormatter: (any UserFormatting)? = nil,
            attachmentNameFormatter: (any AttachmentFormatting)? = nil,
            lastMessageSenderNameFormatter: (any ChannelFormatting)? = nil,
            reactedUserNameFormatter: (any ChannelFormatting)? = nil,
            attachmentIconProvider: (any AttachmentIconProviding)? = nil,
            channelAvatarRenderer: (any ChannelAvatarRendering)? = nil,
            avatarAppearance: AvatarAppearance? = nil,
            presenceStateIconProvider: (any PresenceStateIconProviding)? = nil,
            lastMessageBodyFormatter: (any LastMessageBodyFormatting)? = nil,
            draftMessageBodyFormatter: (any DraftMessageBodyFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._pinnedChannelBackgroundColor = Trackable(reference: reference, referencePath: \.pinnedChannelBackgroundColor)
            self._subjectLabelAppearance = Trackable(reference: reference, referencePath: \.subjectLabelAppearance)
            self._lastMessageLabelAppearance = Trackable(reference: reference, referencePath: \.lastMessageLabelAppearance)
            self._unreadCountLabelAppearance = Trackable(reference: reference, referencePath: \.unreadCountLabelAppearance)
            self._unreadCountMutedStateLabelAppearance = Trackable(reference: reference, referencePath: \.unreadCountMutedStateLabelAppearance)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._dateLabelAppearance = Trackable(reference: reference, referencePath: \.dateLabelAppearance)
            self._lastMessageSenderNameLabelAppearance = Trackable(reference: reference, referencePath: \.lastMessageSenderNameLabelAppearance)
            self._deletedLabelAppearance = Trackable(reference: reference, referencePath: \.deletedLabelAppearance)
            self._deletedStateText = Trackable(reference: reference, referencePath: \.deletedStateText)
            self._draftPrefixLabelAppearance = Trackable(reference: reference, referencePath: \.draftPrefixLabelAppearance)
            self._draftStateText = Trackable(reference: reference, referencePath: \.draftStateText)
            self._typingLabelAppearance = Trackable(reference: reference, referencePath: \.typingLabelAppearance)
            self._mentionLabelAppearance = Trackable(reference: reference, referencePath: \.mentionLabelAppearance)
            self._unreadMentionLabelAppearance = Trackable(reference: reference, referencePath: \.unreadMentionLabelAppearance)
            self._unreadMentionMutedStateLabelAppearance = Trackable(reference: reference, referencePath: \.unreadMentionMutedStateLabelAppearance)
            self._linkLabelAppearance = Trackable(reference: reference, referencePath: \.linkLabelAppearance)
            self._mutedIcon = Trackable(reference: reference, referencePath: \.mutedIcon)
            self._pinIcon = Trackable(reference: reference, referencePath: \.pinIcon)
            self._messageDeliveryStatusIcons = Trackable(reference: reference, referencePath: \.messageDeliveryStatusIcons)
            self._channelNameFormatter = Trackable(reference: reference, referencePath: \.channelNameFormatter)
            self._channelDateFormatter = Trackable(reference: reference, referencePath: \.channelDateFormatter)
            self._unreadCountFormatter = Trackable(reference: reference, referencePath: \.unreadCountFormatter)
            self._typingUserNameFormatter = Trackable(reference: reference, referencePath: \.typingUserNameFormatter)
            self._mentionUserNameFormatter = Trackable(reference: reference, referencePath: \.mentionUserNameFormatter)
            self._attachmentNameFormatter = Trackable(reference: reference, referencePath: \.attachmentNameFormatter)
            self._lastMessageSenderNameFormatter = Trackable(reference: reference, referencePath: \.lastMessageSenderNameFormatter)
            self._reactedUserNameFormatter = Trackable(reference: reference, referencePath: \.reactedUserNameFormatter)
            self._attachmentIconProvider = Trackable(reference: reference, referencePath: \.attachmentIconProvider)
            self._channelAvatarRenderer = Trackable(reference: reference, referencePath: \.channelAvatarRenderer)
            self._avatarAppearance = Trackable(reference: reference, referencePath: \.avatarAppearance)
            self._presenceStateIconProvider = Trackable(reference: reference, referencePath: \.presenceStateIconProvider)
            self._lastMessageBodyFormatter = Trackable(reference: reference, referencePath: \.lastMessageBodyFormatter)
            self._draftMessageBodyFormatter = Trackable(reference: reference, referencePath: \.draftMessageBodyFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let pinnedChannelBackgroundColor { self.pinnedChannelBackgroundColor = pinnedChannelBackgroundColor }
            if let subjectLabelAppearance { self.subjectLabelAppearance = subjectLabelAppearance }
            if let lastMessageLabelAppearance { self.lastMessageLabelAppearance = lastMessageLabelAppearance }
            if let unreadCountLabelAppearance { self.unreadCountLabelAppearance = unreadCountLabelAppearance }
            if let unreadCountMutedStateLabelAppearance { self.unreadCountMutedStateLabelAppearance = unreadCountMutedStateLabelAppearance }
            if let separatorColor { self.separatorColor = separatorColor }
            if let dateLabelAppearance { self.dateLabelAppearance = dateLabelAppearance }
            if let lastMessageSenderNameLabelAppearance { self.lastMessageSenderNameLabelAppearance = lastMessageSenderNameLabelAppearance }
            if let deletedLabelAppearance { self.deletedLabelAppearance = deletedLabelAppearance }
            if let deletedStateText { self.deletedStateText = deletedStateText }
            if let draftPrefixLabelAppearance { self.draftPrefixLabelAppearance = draftPrefixLabelAppearance }
            if let draftStateText { self.draftStateText = draftStateText }
            if let typingLabelAppearance { self.typingLabelAppearance = typingLabelAppearance }
            if let mentionLabelAppearance { self.mentionLabelAppearance = mentionLabelAppearance }
            if let unreadMentionLabelAppearance { self.unreadMentionLabelAppearance = unreadMentionLabelAppearance }
            if let unreadMentionMutedStateLabelAppearance { self.unreadMentionMutedStateLabelAppearance = unreadMentionMutedStateLabelAppearance }
            if let linkLabelAppearance { self.linkLabelAppearance = linkLabelAppearance }
            if let mutedIcon { self.mutedIcon = mutedIcon }
            if let pinIcon { self.pinIcon = pinIcon }
            if let messageDeliveryStatusIcons { self.messageDeliveryStatusIcons = messageDeliveryStatusIcons }
            if let channelNameFormatter { self.channelNameFormatter = channelNameFormatter }
            if let channelDateFormatter { self.channelDateFormatter = channelDateFormatter }
            if let unreadCountFormatter { self.unreadCountFormatter = unreadCountFormatter }
            if let typingUserNameFormatter { self.typingUserNameFormatter = typingUserNameFormatter }
            if let mentionUserNameFormatter { self.mentionUserNameFormatter = mentionUserNameFormatter }
            if let attachmentNameFormatter { self.attachmentNameFormatter = attachmentNameFormatter }
            if let lastMessageSenderNameFormatter { self.lastMessageSenderNameFormatter = lastMessageSenderNameFormatter }
            if let reactedUserNameFormatter { self.reactedUserNameFormatter = reactedUserNameFormatter }
            if let attachmentIconProvider { self.attachmentIconProvider = attachmentIconProvider }
            if let channelAvatarRenderer { self.channelAvatarRenderer = channelAvatarRenderer }
            if let avatarAppearance { self.avatarAppearance = avatarAppearance }
            if let presenceStateIconProvider { self.presenceStateIconProvider = presenceStateIconProvider }
            if let lastMessageBodyFormatter { self.lastMessageBodyFormatter = lastMessageBodyFormatter }
            if let draftMessageBodyFormatter { self.draftMessageBodyFormatter = draftMessageBodyFormatter }
        }
    }
}
