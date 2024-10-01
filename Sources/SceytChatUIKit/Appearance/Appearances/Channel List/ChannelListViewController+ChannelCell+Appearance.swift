//
//  ChannelListViewController+ChannelCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension ChannelListViewController.ChannelCell: AppearanceProviding {
    
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .clear
        public lazy var pinnedChannelBackgroundColor: UIColor = .background
        
        public lazy var subjectLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                        font: Fonts.semiBold.withSize(16))
        public lazy var lastMessageLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                            font: Fonts.regular.withSize(15))
        public lazy var unreadCountLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary,
                                                                            font: Fonts.semiBold.withSize(14),
                                                                            backgroundColor: .accent)
        
        public lazy var unreadCountMutedStateLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary,
                                                                                      font: Fonts.semiBold.withSize(14),
                                                                                      backgroundColor: .surface3)
        public lazy var separatorColor: UIColor = .border
        public lazy var dateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                     font: Fonts.regular.withSize(14))
        public lazy var lastMessageSenderNameLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                                      font: Fonts.regular.withSize(15))
        public lazy var deletedLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                        font: Fonts.regular.with(traits: .traitItalic).withSize(15))
        public lazy var draftPrefixLabelAppearance: LabelAppearance = .init(foregroundColor: DefaultColors.defaultRed,
                                                                            font: Fonts.regular.withSize(15))
        public lazy var typingLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                       font: Fonts.regular.with(traits: .traitItalic).withSize(15))
        public lazy var unreadMentionLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                        font: Fonts.bold.withSize(15),
                                                                        backgroundColor: .accent)
        public lazy var unreadMentionMutedStateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                                  font: Fonts.bold.withSize(15),
                                                                                  backgroundColor: .surface3)
        public lazy var linkLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                     font: Fonts.regular.withSize(15))
        public lazy var mutedIcon: UIImage = .mute
        public lazy var pinIcon: UIImage = .channelPin
        public lazy var messageDeliveryStatusIcons: MessageDeliveryStatusIcons = .init()
        
        public lazy var channelNameFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelNameFormatter
        public lazy var channelDateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.channelDateFormatter
        public lazy var unreadCountFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.unreadCountFormatter
        public lazy var userShortNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userShortNameFormatter
        public lazy var typingUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.typingUserNameFormatter
        public lazy var mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.mentionUserNameFormatter
        public lazy var attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter
        public lazy var lastMessageSenderNameFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelLastMessageSenderNameFormatter
        public lazy var reactedUserNameFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.reactedUserNameFormatter
        public lazy var attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.channelListAttachmentIconProvider
        public lazy var channelDefaultAvatarProvider: any ChannelAvatarProviding = SceytChatUIKit.shared.visualProviders.channelAvatarProvider
        public lazy var presenceStateIconProvider: any PresenceStateIconProviding = SceytChatUIKit.shared.visualProviders.presenceStateIconProvider
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .clear,
            pinnedChannelBackgroundColor: UIColor = .background,
            subjectLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.semiBold.withSize(16)),
            lastMessageLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(15)),
            unreadCountLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary, font: Fonts.semiBold.withSize(14), backgroundColor: .accent),
            unreadCountMutedStateLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary, font: Fonts.semiBold.withSize(14), backgroundColor: .surface3),
            separatorColor: UIColor = .border,
            dateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(14)),
            lastMessageSenderNameLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.regular.withSize(15)),
            deletedLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.with(traits: .traitItalic).withSize(15)),
            draftPrefixLabelAppearance: LabelAppearance = .init(foregroundColor: DefaultColors.defaultRed, font: Fonts.regular.withSize(15)),
            typingLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.with(traits: .traitItalic).withSize(15)),
            mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.bold.withSize(15), backgroundColor: .accent),
            mentionMutedStateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.bold.withSize(15), backgroundColor: .surface3),
            linkLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(15)),
            mutedIcon: UIImage = .mute,
            pinIcon: UIImage = .channelPin,
            messageDeliveryStatusIcons: MessageDeliveryStatusIcons = .init(),
            channelNameFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelNameFormatter,
            channelDateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.channelDateFormatter,
            unreadCountFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.unreadCountFormatter,
            userShortNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userShortNameFormatter,
            typingUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.typingUserNameFormatter,
            mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.mentionUserNameFormatter,
            attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter,
            lastMessageSenderNameFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelLastMessageSenderNameFormatter,
            reactedUserNameFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.reactedUserNameFormatter,
            attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.channelListAttachmentIconProvider,
            channelDefaultAvatarProvider: any ChannelAvatarProviding = SceytChatUIKit.shared.visualProviders.channelAvatarProvider,
            presenceStateIconProvider: any PresenceStateIconProviding = SceytChatUIKit.shared.visualProviders.presenceStateIconProvider
        ) {
            self.backgroundColor = backgroundColor
            self.pinnedChannelBackgroundColor = pinnedChannelBackgroundColor
            self.subjectLabelAppearance = subjectLabelAppearance
            self.lastMessageLabelAppearance = lastMessageLabelAppearance
            self.unreadCountLabelAppearance = unreadCountLabelAppearance
            self.unreadCountMutedStateLabelAppearance = unreadCountMutedStateLabelAppearance
            self.separatorColor = separatorColor
            self.dateLabelAppearance = dateLabelAppearance
            self.lastMessageSenderNameLabelAppearance = lastMessageSenderNameLabelAppearance
            self.deletedLabelAppearance = deletedLabelAppearance
            self.draftPrefixLabelAppearance = draftPrefixLabelAppearance
            self.typingLabelAppearance = typingLabelAppearance
            self.unreadMentionLabelAppearance = mentionLabelAppearance
            self.unreadMentionMutedStateLabelAppearance = mentionMutedStateLabelAppearance
            self.linkLabelAppearance = linkLabelAppearance
            self.mutedIcon = mutedIcon
            self.pinIcon = pinIcon
            self.messageDeliveryStatusIcons = messageDeliveryStatusIcons
            self.channelNameFormatter = channelNameFormatter
            self.channelDateFormatter = channelDateFormatter
            self.unreadCountFormatter = unreadCountFormatter
            self.userShortNameFormatter = userShortNameFormatter
            self.typingUserNameFormatter = typingUserNameFormatter
            self.mentionUserNameFormatter = mentionUserNameFormatter
            self.attachmentNameFormatter = attachmentNameFormatter
            self.lastMessageSenderNameFormatter = lastMessageSenderNameFormatter
            self.reactedUserNameFormatter = reactedUserNameFormatter
            self.attachmentIconProvider = attachmentIconProvider
            self.channelDefaultAvatarProvider = channelDefaultAvatarProvider
            self.presenceStateIconProvider = presenceStateIconProvider
        }
    }
}
