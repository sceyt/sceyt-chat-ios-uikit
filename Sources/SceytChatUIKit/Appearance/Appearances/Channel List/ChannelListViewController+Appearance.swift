//
//  ChannelListViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension ChannelListViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor? = .background
        public lazy var tabBarItemBadgeColor: UIColor? = .stateWarning
        public lazy var connectionIndicatorAppearance: ConnectionStateViewAppearance = .init()
//        public lazy var navigationBarAppearance: NavigationBarAppearance = .init()
        public lazy var searchControllerAppearance: SearchController.Appearance = .init(searchBarAppearance: .init(placeholder: L10n.Channel.List.search))
        public lazy var searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance = ChannelSearchResultsViewController.appearance
        public lazy var emptyViewAppearance: EmptyStateView.Appearance = .init(icon: .emptyChannelList,
                                                                               title: "No Chats yet",
                                                                               message: "You haven’t created channels yet, create one for sending messages.")
        public lazy var cellAppearance: ChannelCell.Appearance = .init()
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor? = .background,
            tabBarItemBadgeColor: UIColor? = .stateWarning,
            connectionIndicatorAppearance: ConnectionStateViewAppearance = .init(),
//            navigationBarAppearance: NavigationBarAppearance = .init(),
            searchControllerAppearance: SearchController.Appearance = .init(searchBarAppearance: .init(placeholder: L10n.Channel.List.search)),
            searchResultControllerAppearance: ChannelSearchResultsViewController.Appearance = ChannelSearchResultsViewController.appearance,
            emptyViewAppearance: EmptyStateView.Appearance = .init(icon: .emptyChannelList,
                                                                   title: "No Chats yet",
                                                                   message: "You haven’t created channels yet, create one for sending messages."),
            cellAppearance: ChannelCell.Appearance = .init()
        ) {
            self.backgroundColor = backgroundColor
            self.tabBarItemBadgeColor = tabBarItemBadgeColor
            self.connectionIndicatorAppearance = connectionIndicatorAppearance
//            self.navigationBarAppearance = navigationBarAppearance
            self.searchControllerAppearance = searchControllerAppearance
            self.searchResultControllerAppearance = searchResultControllerAppearance
            self.emptyViewAppearance = emptyViewAppearance
            self.cellAppearance = cellAppearance
        }
    }
}
