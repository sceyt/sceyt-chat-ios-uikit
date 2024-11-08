//
//  ChannelSearchResultsViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.11.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelSearchResultsViewController {
    
    public static var defaultAppearance = Appearance(
        backgroundColor: .background,
        emptyViewAppearance: EmptyStateView.Appearance(
            reference: EmptyStateView.appearance,
            icon: .noResultsSearch,
            title: L10n.Search.NoResults.title,
            message: L10n.Search.NoResults.message
        ),
        cellAppearance: SearchResultChannelCell.appearance,
        separatorViewAppearance: SeparatorHeaderView.appearance
    )
    
    public class Appearance: ChannelSearchResultsBaseViewController.Appearance {
        
        @Trackable<Appearance, SearchResultChannelCell.Appearance>
        public var cellAppearance: SearchResultChannelCell.Appearance

        public init(
            backgroundColor: UIColor,
            emptyViewAppearance: EmptyStateView.Appearance,
            cellAppearance: SearchResultChannelCell.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance
        ) {
            self._cellAppearance = Trackable(value: cellAppearance)
            
            super.init(
                backgroundColor: backgroundColor,
                emptyViewAppearance: emptyViewAppearance,
                separatorViewAppearance: separatorViewAppearance
            )
        }

        public init(
            reference: ChannelSearchResultsViewController.Appearance,
            backgroundColor: UIColor? = nil,
            emptyViewAppearance: EmptyStateView.Appearance? = nil,
            cellAppearance: SearchResultChannelCell.Appearance? = nil,
            separatorViewAppearance: SeparatorHeaderView.Appearance? = nil
        ) {
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)

            super.init(
                backgroundColor: backgroundColor ?? reference.backgroundColor,
                emptyViewAppearance: emptyViewAppearance ?? reference.emptyViewAppearance,
                separatorViewAppearance: separatorViewAppearance ?? reference.separatorViewAppearance
            )
            
            if let cellAppearance { self.cellAppearance = cellAppearance }
        }
    }
}
