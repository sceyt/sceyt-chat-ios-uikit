//
//  GlobalSearchResultsViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit on 06.04.25
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

extension GlobalSearchResultsViewController {

    public static var defaultAppearance = Appearance(
        backgroundColor: .background,
        emptyViewAppearance: EmptyStateView.Appearance(
            reference: EmptyStateView.appearance,
            icon: .noResultsSearch,
            title: L10n.Search.NoResults.title,
            message: L10n.Search.NoResults.message
        ),
        separatorViewAppearance: SeparatorHeaderView.appearance,
        tabBarAppearance: CategoryTabBar.Appearance(),
        cellAppearance: ChannelListViewController.ChannelCell.Appearance(reference: ChannelListViewController.ChannelCell.appearance)
    )

    public class Appearance: ChannelSearchResultsBaseViewController.Appearance {

        @Trackable<Appearance, CategoryTabBar.Appearance>
        public var tabBarAppearance: CategoryTabBar.Appearance

        @Trackable<Appearance, ChannelListViewController.ChannelCell.Appearance>
        public var cellAppearance: ChannelListViewController.ChannelCell.Appearance

        public init(
            backgroundColor: UIColor?,
            emptyViewAppearance: EmptyStateView.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance,
            tabBarAppearance: CategoryTabBar.Appearance,
            cellAppearance: ChannelListViewController.ChannelCell.Appearance
        ) {
            self._tabBarAppearance = Trackable(value: tabBarAppearance)
            self._cellAppearance = Trackable(value: cellAppearance)
            super.init(
                backgroundColor: backgroundColor,
                emptyViewAppearance: emptyViewAppearance,
                separatorViewAppearance: separatorViewAppearance
            )
        }

        public init(
            reference: GlobalSearchResultsViewController.Appearance,
            backgroundColor: UIColor? = nil,
            emptyViewAppearance: EmptyStateView.Appearance? = nil,
            separatorViewAppearance: SeparatorHeaderView.Appearance? = nil,
            tabBarAppearance: CategoryTabBar.Appearance? = nil,
            cellAppearance: ChannelListViewController.ChannelCell.Appearance? = nil
        ) {
            self._tabBarAppearance = Trackable(reference: reference, referencePath: \.tabBarAppearance)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            super.init(
                backgroundColor: backgroundColor ?? reference.backgroundColor,
                emptyViewAppearance: emptyViewAppearance ?? reference.emptyViewAppearance,
                separatorViewAppearance: separatorViewAppearance ?? reference.separatorViewAppearance
            )
            if let tabBarAppearance { self.tabBarAppearance = tabBarAppearance }
            if let cellAppearance { self.cellAppearance = cellAppearance }
        }
    }
}
