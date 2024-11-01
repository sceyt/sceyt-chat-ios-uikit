//
//  ChannelSelectableSearchResultsViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.11.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelSelectableSearchResultsViewController {
    public static var defaultAppearance = Appearance(
        backgroundColor: .background,
        emptyViewAppearance: EmptyStateView.Appearance(
            reference: EmptyStateView.appearance,
            icon: .noResultsSearch,
            title: L10n.Search.NoResults.title,
            message: L10n.Search.NoResults.message
        ),
        selectableCellAppearance: SelectableChannelCell.appearance,
        separatorViewAppearance: SeparatorHeaderView.appearance
    )
    
    public class Appearance: ChannelSearchResultsBaseViewController.Appearance {
        
        @Trackable<Appearance, SelectableChannelCell.Appearance>
        public var selectableCellAppearance: SelectableChannelCell.Appearance
        
        public init(
            backgroundColor: UIColor,
            emptyViewAppearance: EmptyStateView.Appearance,
            selectableCellAppearance: SelectableChannelCell.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance
        ) {
            self._selectableCellAppearance = Trackable(value: selectableCellAppearance)
            
            super.init(
                backgroundColor: backgroundColor,
                emptyViewAppearance: emptyViewAppearance,
                separatorViewAppearance: separatorViewAppearance
            )
        }
        
        public init(
            reference: ChannelSelectableSearchResultsViewController.Appearance,
            backgroundColor: UIColor? = nil,
            emptyViewAppearance: EmptyStateView.Appearance? = nil,
            selectableCellAppearance: SelectableChannelCell.Appearance? = nil,
            separatorViewAppearance: SeparatorHeaderView.Appearance? = nil
        ) {
            self._selectableCellAppearance = Trackable(reference: reference, referencePath: \.selectableCellAppearance)
            
            super.init(
                backgroundColor: backgroundColor ?? reference.backgroundColor,
                emptyViewAppearance: emptyViewAppearance ?? reference.emptyViewAppearance,
                separatorViewAppearance: separatorViewAppearance ?? reference.separatorViewAppearance
            )
            
            if let selectableCellAppearance { self.selectableCellAppearance = selectableCellAppearance }
        }
    }
}
