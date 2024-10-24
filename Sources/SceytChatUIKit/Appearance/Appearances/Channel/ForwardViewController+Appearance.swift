//
//  ForwardViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ForwardViewController: AppearanceProviding {
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
        searchResultControllerAppearance: ChannelSearchResultsViewController.appearance,
        separatorViewAppearance: SeparatorHeaderView.appearance,
        selectedChannelCellAppearance: SelectedChannelCell.appearance,
        channelCellAppearance: SelectableChannelCell.appearance
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, NavigationBarAppearance.Appearance>
        public var navigationBarAppearance: NavigationBarAppearance.Appearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, SearchController.Appearance>
        public var searchControllerAppearance: SearchController.Appearance
        
        @Trackable<Appearance, ChannelSearchResultsViewController.Appearance>
        public var searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance

        @Trackable<Appearance, SeparatorHeaderView.Appearance>
        public var separatorViewAppearance: SeparatorHeaderView.Appearance
        
        @Trackable<Appearance, SelectedChannelCell.Appearance>
        public var selectedChannelCellAppearance: SelectedChannelCell.Appearance
        
        @Trackable<Appearance, SelectableChannelCell.Appearance>
        public var channelCellAppearance: SelectableChannelCell.Appearance
        
        init(
            navigationBarAppearance: NavigationBarAppearance.Appearance,
            backgroundColor: UIColor,
            searchControllerAppearance: SearchController.Appearance,
            searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance,
            selectedChannelCellAppearance: SelectedChannelCell.Appearance,
            channelCellAppearance: SelectableChannelCell.Appearance
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._searchControllerAppearance = Trackable(value: searchControllerAppearance)
            self._searchResultControllerAppearance = Trackable(value: searchResultControllerAppearance)
            self._separatorViewAppearance = Trackable(value: separatorViewAppearance)
            self._selectedChannelCellAppearance = Trackable(value: selectedChannelCellAppearance)
            self._channelCellAppearance = Trackable(value: channelCellAppearance)
        }
        
        init(
            reference: ForwardViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance.Appearance? = nil,
            backgroundColor: UIColor? = nil,
            searchControllerAppearance: SearchController.Appearance? = nil,
            searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance? = nil,
            separatorViewAppearance: SeparatorHeaderView.Appearance? = nil,
            selectedChannelCellAppearance: SelectedChannelCell.Appearance? = nil,
            channelCellAppearance: SelectableChannelCell.Appearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._searchControllerAppearance = Trackable(reference: reference, referencePath: \.searchControllerAppearance)
            self._searchResultControllerAppearance = Trackable(reference: reference, referencePath: \.searchResultControllerAppearance)
            self._separatorViewAppearance = Trackable(reference: reference, referencePath: \.separatorViewAppearance)
            self._selectedChannelCellAppearance = Trackable(reference: reference, referencePath: \.selectedChannelCellAppearance)
            self._channelCellAppearance = Trackable(reference: reference, referencePath: \.channelCellAppearance)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let searchControllerAppearance { self.searchControllerAppearance = searchControllerAppearance }
            if let searchResultControllerAppearance { self.searchResultControllerAppearance = searchResultControllerAppearance }
            if let separatorViewAppearance { self.separatorViewAppearance = separatorViewAppearance }
            if let selectedChannelCellAppearance { self.selectedChannelCellAppearance = selectedChannelCellAppearance }
            if let channelCellAppearance { self.channelCellAppearance = channelCellAppearance }
        }
    }
}
extension SelectedChannelCell: AppearanceProviding {
    
    public static var appearance = Appearance(
        backgroundColor: .clear,
        labelAppearance: .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(13)
        ),
        titleFormatter: AnyChannelFormatting(SceytChatUIKit.shared.formatters.channelNameFormatter),
        removeIcon: .closeCircle,
        visualProvider: AnyChannelAvatarProviding(SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider)
    )
    
    public class Appearance: SelectedCellAppearance<AnyChannelFormatting, AnyChannelAvatarProviding> {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            titleFormatter: AnyChannelFormatting,
            removeIcon: UIImage,
            visualProvider: AnyChannelAvatarProviding
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            
            super.init(
                labelAppearance: labelAppearance,
                titleFormatter: titleFormatter,
                removeIcon: removeIcon,
                visualProvider: visualProvider
            )
        }

        public init(
            reference: SelectedChannelCell.Appearance,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance,
            titleFormatter: AnyChannelFormatting,
            removeIcon: UIImage,
            visualProvider: AnyChannelAvatarProviding
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            
            super.init(
                labelAppearance: labelAppearance,
                titleFormatter: titleFormatter,
                removeIcon: removeIcon,
                visualProvider: visualProvider
            )
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
        }
    }
}

