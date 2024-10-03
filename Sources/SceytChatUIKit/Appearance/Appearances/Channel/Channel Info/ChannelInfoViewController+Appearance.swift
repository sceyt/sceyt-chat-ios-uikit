//
//  ChannelInfoViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .backgroundSecondary
        public var separatorColor: UIColor = .border
        
        public var titleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.bold.withSize(16)
        )
        
        public var subtitleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        )
        
        public var detailsCellAppearance: DetailsCell.Appearance = Components.channelInfoDetailsCell.appearance
        public var descriptionCellAppearance: DescriptionCell.Appearance = Components.channelInfoDescriptionCell.appearance
        public var uriCellAppearance: OptionCell.Appearance = Components.channelInfoOptionCell.appearance
        public var optionItemCellAppearance: OptionCell.Appearance = .init(
            descriptionLabelAppearance: .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(15)
            ),
            switchTintColor: .accent,
            accessoryImage: .chevron
        )
        public var optionTitles: OptionTitles = .init()
        public var optionIcons: OptionIcons = .init()
        
        public var segmentedControlAppearance: SegmentedControl.Appearance = Components.segmentedControl.appearance
        public var mediaCollectionAppearance: MediaCollectionView.Appearance = Components.channelInfoMediaCollectionView.appearance
        public var fileCollectionAppearance: FileCollectionView.Appearance = Components.channelInfoFileCollectionView.appearance
        public var voiceCollectionAppearance: VoiceCollectionView.Appearance = Components.channelInfoVoiceCollectionView.appearance
        public var linkCollectionAppearance: LinkCollectionView.Appearance = Components.channelInfoLinkCollectionView.appearance
        
        public var moreIcon: UIImage = .channelProfileMore
        
        public init(
            backgroundColor: UIColor = .backgroundSecondary,
            separatorColor: UIColor = .border,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.bold.withSize(16)
            ),
            subtitleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            detailsCellAppearance: DetailsCell.Appearance = SceytChatUIKit.Components.channelInfoDetailsCell.appearance,
            descriptionCellAppearance: DescriptionCell.Appearance = SceytChatUIKit.Components.channelInfoDescriptionCell.appearance,
            uriCellAppearance: OptionCell.Appearance = SceytChatUIKit.Components.channelInfoOptionCell.appearance,
            optionItemCellAppearance: OptionCell.Appearance = .init(
                descriptionLabelAppearance: .init(
                    foregroundColor: .secondaryText,
                    font: Fonts.regular.withSize(15)
                ),
                switchTintColor: .accent,
                accessoryImage: .chevron
            ),
            optionTitles: OptionTitles = .init(),
            optionIcons: OptionIcons = .init(),
            segmentedControlAppearance: SegmentedControl.Appearance = SceytChatUIKit.Components.segmentedControl.appearance,
            mediaCollectionAppearance: MediaCollectionView.Appearance = SceytChatUIKit.Components.channelInfoMediaCollectionView.appearance,
            fileCollectionAppearance: FileCollectionView.Appearance = SceytChatUIKit.Components.channelInfoFileCollectionView.appearance,
            voiceCollectionAppearance: VoiceCollectionView.Appearance = SceytChatUIKit.Components.channelInfoVoiceCollectionView.appearance,
            linkCollectionAppearance: LinkCollectionView.Appearance = SceytChatUIKit.Components.channelInfoLinkCollectionView.appearance
        ) {
            self.backgroundColor = backgroundColor
            self.separatorColor = separatorColor
            self.titleLabelAppearance = titleLabelAppearance
            self.subtitleLabelAppearance = subtitleLabelAppearance
            self.detailsCellAppearance = detailsCellAppearance
            self.descriptionCellAppearance = descriptionCellAppearance
            self.uriCellAppearance = uriCellAppearance
            self.optionItemCellAppearance = optionItemCellAppearance
            self.optionTitles = optionTitles
            self.optionIcons = optionIcons
            self.segmentedControlAppearance = segmentedControlAppearance
            self.mediaCollectionAppearance = mediaCollectionAppearance
            self.fileCollectionAppearance = fileCollectionAppearance
            self.voiceCollectionAppearance = voiceCollectionAppearance
            self.linkCollectionAppearance = linkCollectionAppearance
        }
    }
}

extension ChannelInfoViewController {
    public struct OptionIcons {
        public var uriIcon: UIImage = .channelProfileURI
        public var notificationsIcon: UIImage = .channelProfileBell
        public var autoDeleteMessagesIcon: UIImage = .channelProfileAutoDeleteMessages
        public var subscribersIcon: UIImage = .channelProfileMembers
        public var membersIcon: UIImage = .channelProfileMembers
        public var adminsIcon: UIImage = .channelProfileAdmins
        public var searchIcon: UIImage = .searchFill
        
        public init(uriIcon: UIImage = .channelProfileURI,
                    notificationsIcon: UIImage = .channelProfileBell,
                    autoDeleteMessagesIcon: UIImage = .channelProfileAutoDeleteMessages,
                    subscribersIcon: UIImage = .channelProfileMembers,
                    membersIcon: UIImage = .channelProfileMembers,
                    adminsIcon: UIImage = .channelProfileAdmins,
                    searchIcon: UIImage = .searchFill) {
            self.uriIcon = uriIcon
            self.notificationsIcon = notificationsIcon
            self.autoDeleteMessagesIcon = autoDeleteMessagesIcon
            self.subscribersIcon = subscribersIcon
            self.membersIcon = membersIcon
            self.adminsIcon = adminsIcon
            self.searchIcon = searchIcon
        }
    }
}

extension ChannelInfoViewController {
    public struct OptionTitles {
        public var notificationsTitleText: String = L10n.Channel.Info.notifications
        public var autoDeleteMessagesTitleText: String = L10n.Channel.Info.Item.Title.autoDeleteMessages
        public var subscribersTitleText: String = L10n.Channel.Info.Item.Title.subscribers
        public var membersTitleText: String = L10n.Channel.Info.Item.Title.members
        public var adminsTitleText: String = L10n.Channel.Info.Item.Title.admins
        public var searchTitleText: String = L10n.Channel.Info.Item.Title.messageSearch
        
        public init(notificationsTitleText: String = L10n.Channel.Info.notifications,
                    autoDeleteMessagesTitleText: String = L10n.Channel.Info.Item.Title.autoDeleteMessages,
                    subscribersTitleText: String = L10n.Channel.Info.Item.Title.subscribers,
                    membersTitleText: String = L10n.Channel.Info.Item.Title.members,
                    adminsTitleText: String = L10n.Channel.Info.Item.Title.admins,
                    searchTitleText: String = L10n.Channel.Info.Item.Title.messageSearch) {
            self.notificationsTitleText = notificationsTitleText
            self.autoDeleteMessagesTitleText = autoDeleteMessagesTitleText
            self.subscribersTitleText = subscribersTitleText
            self.membersTitleText = membersTitleText
            self.adminsTitleText = adminsTitleText
            self.searchTitleText = searchTitleText
        }
    }
}
