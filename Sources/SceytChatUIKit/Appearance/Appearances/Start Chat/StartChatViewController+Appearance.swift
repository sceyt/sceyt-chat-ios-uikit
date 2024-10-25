//
//  StartChatViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension StartChatViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: NavigationBarAppearance.appearance,
        backgroundColor: .background,
        searchControllerAppearance: SearchController.Appearance(
            reference: SearchController.appearance,
            searchBarAppearance: .init(
                reference: SearchBarAppearance.appearance,
                placeholder: L10n.Channel.List.search
            )
        ),
        createGroupText: L10n.Channel.New.createPrivate,
        createGroupLabelAppearance: .init(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(16)
        ),
        createGroupIcon: .channelCreatePrivate,
        createChannelText: L10n.Channel.New.createPublic,
        createChannelLabelAppearance: .init(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(16)
        ),
        createChannelIcon: .channelCreatePublic,
        separatorViewAppearance: .init(
            reference: SeparatorHeaderView.appearance,
            title: L10n.Channel.New.userSectionTitle
        ),
        userCellAppearance: UserCell.appearance
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, NavigationBarAppearance>
        public var navigationBarAppearance: NavigationBarAppearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, SearchController.Appearance>
        public var searchControllerAppearance: SearchController.Appearance
        
        @Trackable<Appearance, String>
        public var createGroupText: String
        
        @Trackable<Appearance, LabelAppearance>
        public var createGroupLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIImage>
        public var createGroupIcon: UIImage
        
        @Trackable<Appearance, String>
        public var createChannelText: String
        
        @Trackable<Appearance, LabelAppearance>
        public var createChannelLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIImage>
        public var createChannelIcon: UIImage
        
        @Trackable<Appearance, SeparatorHeaderView.Appearance>
        public var separatorViewAppearance: SeparatorHeaderView.Appearance
        
        @Trackable<Appearance, UserCell.Appearance>
        public var userCellAppearance: UserCell.Appearance
        
        public init(
            navigationBarAppearance: NavigationBarAppearance,
            backgroundColor: UIColor,
            searchControllerAppearance: SearchController.Appearance,
            createGroupText: String,
            createGroupLabelAppearance: LabelAppearance,
            createGroupIcon: UIImage,
            createChannelText: String,
            createChannelLabelAppearance: LabelAppearance,
            createChannelIcon: UIImage,
            separatorViewAppearance: SeparatorHeaderView.Appearance,
            userCellAppearance: UserCell.Appearance
        ){
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._searchControllerAppearance = Trackable(value: searchControllerAppearance)
            self._createGroupText = Trackable(value: createGroupText)
            self._createGroupLabelAppearance = Trackable(value: createGroupLabelAppearance)
            self._createGroupIcon = Trackable(value: createGroupIcon)
            self._createChannelText = Trackable(value: createChannelText)
            self._createChannelLabelAppearance = Trackable(value: createChannelLabelAppearance)
            self._createChannelIcon = Trackable(value: createChannelIcon)
            self._separatorViewAppearance = Trackable(value: separatorViewAppearance)
            self._userCellAppearance = Trackable(value: userCellAppearance)
        }
        
        public init(
            reference: StartChatViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance? = nil,
            backgroundColor: UIColor? = nil,
            searchControllerAppearance: SearchController.Appearance? = nil,
            createGroupText: String? = nil,
            createGroupLabelAppearance: LabelAppearance? = nil,
            createGroupIcon: UIImage? = nil,
            createChannelText: String? = nil,
            createChannelLabelAppearance: LabelAppearance? = nil,
            createChannelIcon: UIImage? = nil,
            separatorViewAppearance: SeparatorHeaderView.Appearance? = nil,
            userCellAppearance: UserCell.Appearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._searchControllerAppearance = Trackable(reference: reference, referencePath: \.searchControllerAppearance)
            self._createGroupText = Trackable(reference: reference, referencePath: \.createGroupText)
            self._createGroupLabelAppearance = Trackable(reference: reference, referencePath: \.createGroupLabelAppearance)
            self._createGroupIcon = Trackable(reference: reference, referencePath: \.createGroupIcon)
            self._createChannelText = Trackable(reference: reference, referencePath: \.createChannelText)
            self._createChannelLabelAppearance = Trackable(reference: reference, referencePath: \.createChannelLabelAppearance)
            self._createChannelIcon = Trackable(reference: reference, referencePath: \.createChannelIcon)
            self._separatorViewAppearance = Trackable(reference: reference, referencePath: \.separatorViewAppearance)
            self._userCellAppearance = Trackable(reference: reference, referencePath: \.userCellAppearance)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let searchControllerAppearance { self.searchControllerAppearance = searchControllerAppearance }
            if let createGroupText { self.createGroupText = createGroupText }
            if let createGroupLabelAppearance { self.createGroupLabelAppearance = createGroupLabelAppearance }
            if let createGroupIcon { self.createGroupIcon = createGroupIcon }
            if let createChannelText { self.createChannelText = createChannelText }
            if let createChannelLabelAppearance { self.createChannelLabelAppearance = createChannelLabelAppearance }
            if let createChannelIcon { self.createChannelIcon = createChannelIcon }
            if let separatorViewAppearance { self.separatorViewAppearance = separatorViewAppearance }
            if let userCellAppearance { self.userCellAppearance = userCellAppearance }
        }
    }
}

