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
        tabBarAppearance: CategoryTabBar.Appearance()
    )

    public class Appearance: ChannelSearchResultsBaseViewController.Appearance {

        @Trackable<Appearance, CategoryTabBar.Appearance>
        public var tabBarAppearance: CategoryTabBar.Appearance

        public init(
            backgroundColor: UIColor?,
            emptyViewAppearance: EmptyStateView.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance,
            tabBarAppearance: CategoryTabBar.Appearance
        ) {
            self._tabBarAppearance = Trackable(value: tabBarAppearance)
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
            tabBarAppearance: CategoryTabBar.Appearance? = nil
        ) {
            self._tabBarAppearance = Trackable(reference: reference, referencePath: \.tabBarAppearance)
            super.init(
                backgroundColor: backgroundColor ?? reference.backgroundColor,
                emptyViewAppearance: emptyViewAppearance ?? reference.emptyViewAppearance,
                separatorViewAppearance: separatorViewAppearance ?? reference.separatorViewAppearance
            )
            if let tabBarAppearance { self.tabBarAppearance = tabBarAppearance }
        }
    }
}
