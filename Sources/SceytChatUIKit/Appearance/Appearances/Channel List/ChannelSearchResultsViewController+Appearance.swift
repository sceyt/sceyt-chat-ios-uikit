//
//  ChannelSearchResultsViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension ChannelSearchResultsViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .background
        public var emptyViewAppearance: EmptyStateView.Appearance = .init(
            icon: .noResultsSearch,
            title: "No Results",
            message: "There were no results found."
        )
        public var cellAppearance: SearchResultChannelCell.Appearance = SearchResultChannelCell.appearance
        public var separatorViewAppearance: SeparatorHeaderView.Appearance = SeparatorHeaderView.appearance
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor? = .background,
            emptyViewAppearance: EmptyStateView.Appearance = .init(
                icon: .noResultsSearch,
                title: "No Results",
                message: "There were no results found."
            ),
            cellAppearance: SearchResultChannelCell.Appearance = SearchResultChannelCell.appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance = SeparatorHeaderView.appearance
        ) {
            self.backgroundColor = backgroundColor
            self.emptyViewAppearance = emptyViewAppearance
            self.cellAppearance = cellAppearance
            self.separatorViewAppearance = separatorViewAppearance
        }
    }
}
