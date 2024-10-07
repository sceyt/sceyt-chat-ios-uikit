//
//  ChannelInfoViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: {
            $0.appearance.standardAppearance?.backgroundColor = .surface1
            return $0.appearance
        }(NavigationBarAppearance()),
        backgroundColor: .backgroundSecondary,
        separatorColor: .border,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.bold.withSize(16)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        detailsCellAppearance: SceytChatUIKit.Components.channelInfoDetailsCell.appearance,
        descriptionCellAppearance: SceytChatUIKit.Components.channelInfoDescriptionCell.appearance,
        uriCellAppearance: SceytChatUIKit.Components.channelInfoOptionCell.appearance,
        optionItemCellAppearance: OptionCell.Appearance(
            reference: OptionCell.appearance,
            descriptionLabelAppearance: LabelAppearance(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(15)
            ),
            switchTintColor: .accent,
            accessoryImage: .chevron
        ),
        optionTitles: OptionTitles(),
        optionIcons: OptionIcons(),
        segmentedControlAppearance: SceytChatUIKit.Components.segmentedControl.appearance,
        mediaCollectionAppearance: SceytChatUIKit.Components.channelInfoMediaCollectionView.appearance,
        fileCollectionAppearance: SceytChatUIKit.Components.channelInfoFileCollectionView.appearance,
        voiceCollectionAppearance: SceytChatUIKit.Components.channelInfoVoiceCollectionView.appearance,
        linkCollectionAppearance: SceytChatUIKit.Components.channelInfoLinkCollectionView.appearance,
        moreIcon: .channelProfileMore
    )
    
    public struct Appearance {
        @Trackable<Appearance, NavigationBarAppearance.Appearance>
        public var navigationBarAppearance: NavigationBarAppearance.Appearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var subtitleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, DetailsCell.Appearance>
        public var detailsCellAppearance: DetailsCell.Appearance
        
        @Trackable<Appearance, DescriptionCell.Appearance>
        public var descriptionCellAppearance: DescriptionCell.Appearance
        
        @Trackable<Appearance, OptionCell.Appearance>
        public var uriCellAppearance: OptionCell.Appearance
        
        @Trackable<Appearance, OptionCell.Appearance>
        public var optionItemCellAppearance: OptionCell.Appearance
        
        @Trackable<Appearance, OptionTitles>
        public var optionTitles: OptionTitles
        
        @Trackable<Appearance, OptionIcons>
        public var optionIcons: OptionIcons
        
        @Trackable<Appearance, SegmentedControl.Appearance>
        public var segmentedControlAppearance: SegmentedControl.Appearance
        
        @Trackable<Appearance, MediaCollectionView.Appearance>
        public var mediaCollectionAppearance: MediaCollectionView.Appearance
        
        @Trackable<Appearance, FileCollectionView.Appearance>
        public var fileCollectionAppearance: FileCollectionView.Appearance
        
        @Trackable<Appearance, VoiceCollectionView.Appearance>
        public var voiceCollectionAppearance: VoiceCollectionView.Appearance
        
        @Trackable<Appearance, LinkCollectionView.Appearance>
        public var linkCollectionAppearance: LinkCollectionView.Appearance
        
        @Trackable<Appearance, UIImage>
        public var moreIcon: UIImage
        
        public init(
            navigationBarAppearance: NavigationBarAppearance.Appearance,
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            detailsCellAppearance: DetailsCell.Appearance,
            descriptionCellAppearance: DescriptionCell.Appearance,
            uriCellAppearance: OptionCell.Appearance,
            optionItemCellAppearance: OptionCell.Appearance,
            optionTitles: OptionTitles,
            optionIcons: OptionIcons,
            segmentedControlAppearance: SegmentedControl.Appearance,
            mediaCollectionAppearance: MediaCollectionView.Appearance,
            fileCollectionAppearance: FileCollectionView.Appearance,
            voiceCollectionAppearance: VoiceCollectionView.Appearance,
            linkCollectionAppearance: LinkCollectionView.Appearance,
            moreIcon: UIImage
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
            self._detailsCellAppearance = Trackable(value: detailsCellAppearance)
            self._descriptionCellAppearance = Trackable(value: descriptionCellAppearance)
            self._uriCellAppearance = Trackable(value: uriCellAppearance)
            self._optionItemCellAppearance = Trackable(value: optionItemCellAppearance)
            self._optionTitles = Trackable(value: optionTitles)
            self._optionIcons = Trackable(value: optionIcons)
            self._segmentedControlAppearance = Trackable(value: segmentedControlAppearance)
            self._mediaCollectionAppearance = Trackable(value: mediaCollectionAppearance)
            self._fileCollectionAppearance = Trackable(value: fileCollectionAppearance)
            self._voiceCollectionAppearance = Trackable(value: voiceCollectionAppearance)
            self._linkCollectionAppearance = Trackable(value: linkCollectionAppearance)
            self._moreIcon = Trackable(value: moreIcon)
        }
        
        public init(
            reference: ChannelInfoViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance.Appearance? = nil,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            detailsCellAppearance: DetailsCell.Appearance? = nil,
            descriptionCellAppearance: DescriptionCell.Appearance? = nil,
            uriCellAppearance: OptionCell.Appearance? = nil,
            optionItemCellAppearance: OptionCell.Appearance? = nil,
            optionTitles: OptionTitles? = nil,
            optionIcons: OptionIcons? = nil,
            segmentedControlAppearance: SegmentedControl.Appearance? = nil,
            mediaCollectionAppearance: MediaCollectionView.Appearance? = nil,
            fileCollectionAppearance: FileCollectionView.Appearance? = nil,
            voiceCollectionAppearance: VoiceCollectionView.Appearance? = nil,
            linkCollectionAppearance: LinkCollectionView.Appearance? = nil,
            moreIcon: UIImage? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(reference: reference, referencePath: \.subtitleLabelAppearance)
            self._detailsCellAppearance = Trackable(reference: reference, referencePath: \.detailsCellAppearance)
            self._descriptionCellAppearance = Trackable(reference: reference, referencePath: \.descriptionCellAppearance)
            self._uriCellAppearance = Trackable(reference: reference, referencePath: \.uriCellAppearance)
            self._optionItemCellAppearance = Trackable(reference: reference, referencePath: \.optionItemCellAppearance)
            self._optionTitles = Trackable(reference: reference, referencePath: \.optionTitles)
            self._optionIcons = Trackable(reference: reference, referencePath: \.optionIcons)
            self._segmentedControlAppearance = Trackable(reference: reference, referencePath: \.segmentedControlAppearance)
            self._mediaCollectionAppearance = Trackable(reference: reference, referencePath: \.mediaCollectionAppearance)
            self._fileCollectionAppearance = Trackable(reference: reference, referencePath: \.fileCollectionAppearance)
            self._voiceCollectionAppearance = Trackable(reference: reference, referencePath: \.voiceCollectionAppearance)
            self._linkCollectionAppearance = Trackable(reference: reference, referencePath: \.linkCollectionAppearance)
            self._moreIcon = Trackable(reference: reference, referencePath: \.moreIcon)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let subtitleLabelAppearance { self.subtitleLabelAppearance = subtitleLabelAppearance }
            if let detailsCellAppearance { self.detailsCellAppearance = detailsCellAppearance }
            if let descriptionCellAppearance { self.descriptionCellAppearance = descriptionCellAppearance }
            if let uriCellAppearance { self.uriCellAppearance = uriCellAppearance }
            if let optionItemCellAppearance { self.optionItemCellAppearance = optionItemCellAppearance }
            if let optionTitles { self.optionTitles = optionTitles }
            if let optionIcons { self.optionIcons = optionIcons }
            if let segmentedControlAppearance { self.segmentedControlAppearance = segmentedControlAppearance }
            if let mediaCollectionAppearance { self.mediaCollectionAppearance = mediaCollectionAppearance }
            if let fileCollectionAppearance { self.fileCollectionAppearance = fileCollectionAppearance }
            if let voiceCollectionAppearance { self.voiceCollectionAppearance = voiceCollectionAppearance }
            if let linkCollectionAppearance { self.linkCollectionAppearance = linkCollectionAppearance }
            if let moreIcon { self.moreIcon = moreIcon }
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
        
        public init(
            uriIcon: UIImage = .channelProfileURI,
                    notificationsIcon: UIImage = .channelProfileBell,
                    autoDeleteMessagesIcon: UIImage = .channelProfileAutoDeleteMessages,
                    subscribersIcon: UIImage = .channelProfileMembers,
                    membersIcon: UIImage = .channelProfileMembers,
                    adminsIcon: UIImage = .channelProfileAdmins,
                    searchIcon: UIImage = .searchFill
        ) {
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
        
        public init(
            notificationsTitleText: String = L10n.Channel.Info.notifications,
                    autoDeleteMessagesTitleText: String = L10n.Channel.Info.Item.Title.autoDeleteMessages,
                    subscribersTitleText: String = L10n.Channel.Info.Item.Title.subscribers,
                    membersTitleText: String = L10n.Channel.Info.Item.Title.members,
                    adminsTitleText: String = L10n.Channel.Info.Item.Title.admins,
                    searchTitleText: String = L10n.Channel.Info.Item.Title.messageSearch
        ) {
            self.notificationsTitleText = notificationsTitleText
            self.autoDeleteMessagesTitleText = autoDeleteMessagesTitleText
            self.subscribersTitleText = subscribersTitleText
            self.membersTitleText = membersTitleText
            self.adminsTitleText = adminsTitleText
            self.searchTitleText = searchTitleText
        }
    }
}
