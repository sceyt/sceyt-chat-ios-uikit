//
//  SelectUsersViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SelectUsersViewController: AppearanceProviding {
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
        separatorViewAppearance: .init(
            reference: SeparatorHeaderView.appearance,
            title: L10n.Channel.New.userSectionTitle
        ),
        userCellAppearance: SelectableUserCell.appearance
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, NavigationBarAppearance>
        public var navigationBarAppearance: NavigationBarAppearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, SearchController.Appearance>
        public var searchControllerAppearance: SearchController.Appearance

        @Trackable<Appearance, SeparatorHeaderView.Appearance>
        public var separatorViewAppearance: SeparatorHeaderView.Appearance
        
        @Trackable<Appearance, SelectableUserCell.Appearance>
        public var userCellAppearance: SelectableUserCell.Appearance

        public init(
            navigationBarAppearance: NavigationBarAppearance,
            backgroundColor: UIColor,
            searchControllerAppearance: SearchController.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance,
            userCellAppearance: SelectableUserCell.Appearance
        ){
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._searchControllerAppearance = Trackable(value: searchControllerAppearance)
            self._separatorViewAppearance = Trackable(value: separatorViewAppearance)
            self._userCellAppearance = Trackable(value: userCellAppearance)
        }
        
        public init(
            reference: SelectUsersViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance? = nil,
            backgroundColor: UIColor? = nil,
            searchControllerAppearance: SearchController.Appearance? = nil,
            separatorViewAppearance: SeparatorHeaderView.Appearance? = nil,
            userCellAppearance: SelectableUserCell.Appearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._searchControllerAppearance = Trackable(reference: reference, referencePath: \.searchControllerAppearance)
            self._separatorViewAppearance = Trackable(reference: reference, referencePath: \.separatorViewAppearance)
            self._userCellAppearance = Trackable(reference: reference, referencePath: \.userCellAppearance)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let searchControllerAppearance { self.searchControllerAppearance = searchControllerAppearance }
            if let separatorViewAppearance { self.separatorViewAppearance = separatorViewAppearance }
            if let userCellAppearance { self.userCellAppearance = userCellAppearance }
        }
    }
}
