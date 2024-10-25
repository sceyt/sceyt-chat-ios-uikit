//
//  ChannelListViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension ChannelListViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: {
            $0.standardAppearance?.backgroundColor = .surface1
            return $0
        }(NavigationBarAppearance.appearance),
        backgroundColor: .background,
        tabBarItemBadgeColor: .stateWarning,
        connectionIndicatorAppearance: ConnectionStateViewAppearance(
            reference: .appearance
        ),
        searchControllerAppearance: SearchController.Appearance(
            reference: SearchController.appearance,
            searchBarAppearance: .init(
                reference: SearchBarAppearance.appearance,
                placeholder: L10n.Channel.List.search
            )
        ),
        searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance(
            reference: ChannelSearchResultsViewController.appearance
        ),
        emptyViewAppearance: EmptyStateView.Appearance(
            reference: EmptyStateView.appearance,
            icon: .emptyChannelList,
            title: "No Chats yet",
            message: "You haven’t created channels yet, create one for sending messages."
        ),
        cellAppearance: ChannelCell.Appearance(
            reference: ChannelCell.appearance
        )
    )
    
    public class Appearance {
                
        @Trackable<Appearance, NavigationBarAppearance>
        public var navigationBarAppearance: NavigationBarAppearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var tabBarItemBadgeColor: UIColor
        
        @Trackable<Appearance, ConnectionStateViewAppearance>
        public var connectionIndicatorAppearance: ConnectionStateViewAppearance
        
        @Trackable<Appearance, SearchController.Appearance>
        public var searchControllerAppearance: SearchController.Appearance
        
        @Trackable<Appearance, ChannelSearchResultsViewController.Appearance>
        public var searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance
        
        @Trackable<Appearance, EmptyStateView.Appearance>
        public var emptyViewAppearance: EmptyStateView.Appearance
        
        @Trackable<Appearance, ChannelCell.Appearance>
        public var cellAppearance: ChannelCell.Appearance
        
        // Initializer with default values
        public init(
            navigationBarAppearance: NavigationBarAppearance,
            backgroundColor: UIColor,
            tabBarItemBadgeColor: UIColor,
            connectionIndicatorAppearance: ConnectionStateViewAppearance,
            searchControllerAppearance: SearchController.Appearance,
            searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance,
            emptyViewAppearance: EmptyStateView.Appearance,
            cellAppearance: ChannelCell.Appearance
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._tabBarItemBadgeColor = Trackable(value: tabBarItemBadgeColor)
            self._connectionIndicatorAppearance = Trackable(value: connectionIndicatorAppearance)
            self._searchControllerAppearance = Trackable(value: searchControllerAppearance)
            self._searchResultControllerAppearance = Trackable(value: searchResultControllerAppearance)
            self._emptyViewAppearance = Trackable(value: emptyViewAppearance)
            self._cellAppearance = Trackable(value: cellAppearance)
        }
        
        public init(
            reference: ChannelListViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance? = nil,
            backgroundColor: UIColor? = nil,
            tabBarItemBadgeColor: UIColor? = nil,
            connectionIndicatorAppearance: ConnectionStateViewAppearance? = nil,
            searchControllerAppearance: SearchController.Appearance? = nil,
            searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance? = nil,
            emptyViewAppearance: EmptyStateView.Appearance? = nil,
            cellAppearance: ChannelCell.Appearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._tabBarItemBadgeColor = Trackable(reference: reference, referencePath: \.tabBarItemBadgeColor)
            self._connectionIndicatorAppearance = Trackable(reference: reference, referencePath: \.connectionIndicatorAppearance)
            self._searchControllerAppearance = Trackable(reference: reference, referencePath: \.searchControllerAppearance)
            self._searchResultControllerAppearance = Trackable(reference: reference, referencePath: \.searchResultControllerAppearance)
            self._emptyViewAppearance = Trackable(reference: reference, referencePath: \.emptyViewAppearance)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let tabBarItemBadgeColor { self.tabBarItemBadgeColor = tabBarItemBadgeColor }
            if let connectionIndicatorAppearance { self.connectionIndicatorAppearance = connectionIndicatorAppearance }
            if let searchControllerAppearance { self.searchControllerAppearance = searchControllerAppearance }
            if let searchResultControllerAppearance { self.searchResultControllerAppearance = searchResultControllerAppearance }
            if let emptyViewAppearance { self.emptyViewAppearance = emptyViewAppearance }
            if let cellAppearance { self.cellAppearance = cellAppearance }
        }
    }
}
