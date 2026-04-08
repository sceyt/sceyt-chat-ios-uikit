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
        separatorViewAppearance: .init(
            reference: Components.separatorHeaderView.appearance,
            title: L10n.Search.Category.chats
        ),
        channelsSeparatorViewAppearance: .init(
            reference: Components.separatorHeaderView.appearance,
            title: L10n.Search.Category.channels
        ),
        tabBarAppearance: CategoryTabBar.Appearance(),
        cellAppearance: ChannelListViewController.ChannelCell.Appearance(reference: ChannelListViewController.ChannelCell.appearance),
        userBarAppearance: GlobalSearchUserBarView.Appearance(reference: GlobalSearchUserBarView.appearance)
    )

    public class Appearance: ChannelSearchResultsBaseViewController.Appearance {

        @Trackable<Appearance, SeparatorHeaderView.Appearance>
        public var channelsSeparatorViewAppearance: SeparatorHeaderView.Appearance

        @Trackable<Appearance, CategoryTabBar.Appearance>
        public var tabBarAppearance: CategoryTabBar.Appearance

        @Trackable<Appearance, ChannelListViewController.ChannelCell.Appearance>
        public var cellAppearance: ChannelListViewController.ChannelCell.Appearance

        @Trackable<Appearance, GlobalSearchUserBarView.Appearance>
        public var userBarAppearance: GlobalSearchUserBarView.Appearance

        public init(
            backgroundColor: UIColor?,
            emptyViewAppearance: EmptyStateView.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance,
            channelsSeparatorViewAppearance: SeparatorHeaderView.Appearance,
            tabBarAppearance: CategoryTabBar.Appearance,
            cellAppearance: ChannelListViewController.ChannelCell.Appearance,
            userBarAppearance: GlobalSearchUserBarView.Appearance
        ) {
            self._channelsSeparatorViewAppearance = Trackable(value: channelsSeparatorViewAppearance)
            self._tabBarAppearance = Trackable(value: tabBarAppearance)
            self._cellAppearance = Trackable(value: cellAppearance)
            self._userBarAppearance = Trackable(value: userBarAppearance)
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
            channelsSeparatorViewAppearance: SeparatorHeaderView.Appearance? = nil,
            tabBarAppearance: CategoryTabBar.Appearance? = nil,
            cellAppearance: ChannelListViewController.ChannelCell.Appearance? = nil,
            userBarAppearance: GlobalSearchUserBarView.Appearance? = nil
        ) {
            self._channelsSeparatorViewAppearance = Trackable(reference: reference, referencePath: \.channelsSeparatorViewAppearance)
            self._tabBarAppearance = Trackable(reference: reference, referencePath: \.tabBarAppearance)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            self._userBarAppearance = Trackable(reference: reference, referencePath: \.userBarAppearance)
            super.init(
                backgroundColor: backgroundColor ?? reference.backgroundColor,
                emptyViewAppearance: emptyViewAppearance ?? reference.emptyViewAppearance,
                separatorViewAppearance: separatorViewAppearance ?? reference.separatorViewAppearance
            )
            if let channelsSeparatorViewAppearance { self.channelsSeparatorViewAppearance = channelsSeparatorViewAppearance }
            if let tabBarAppearance { self.tabBarAppearance = tabBarAppearance }
            if let cellAppearance { self.cellAppearance = cellAppearance }
            if let userBarAppearance { self.userBarAppearance = userBarAppearance }
        }
    }
}
