//
//  ChannelSearchResultsBaseViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension ChannelSearchResultsBaseViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        emptyViewAppearance: EmptyStateView.Appearance(
            reference: EmptyStateView.appearance,
            icon: .noResultsSearch,
            title: L10n.Search.NoResults.title,
            message: L10n.Search.NoResults.message
        ),
        separatorViewAppearance: SeparatorHeaderView.appearance
    )
    
    public class Appearance {
        @Trackable<Appearance, UIColor?>
        public var backgroundColor: UIColor?
        
        @Trackable<Appearance, EmptyStateView.Appearance>
        public var emptyViewAppearance: EmptyStateView.Appearance
                
        @Trackable<Appearance, SeparatorHeaderView.Appearance>
        public var separatorViewAppearance: SeparatorHeaderView.Appearance
        
        // Initializer with all parameters
        public init(
            backgroundColor: UIColor?,
            emptyViewAppearance: EmptyStateView.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._emptyViewAppearance = Trackable(value: emptyViewAppearance)
            self._separatorViewAppearance = Trackable(value: separatorViewAppearance)
        }
    }
}
