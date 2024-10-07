//
//  ChannelSearchResultsViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension ChannelSearchResultsViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        emptyViewAppearance: EmptyStateView.Appearance(
            reference: EmptyStateView.appearance,
            icon: .noResultsSearch,
            title: "No Results",
            message: "There were no results found."
        ),
        cellAppearance: SearchResultChannelCell.appearance,
        separatorViewAppearance: SeparatorHeaderView.appearance
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor?>
        public var backgroundColor: UIColor?
        
        @Trackable<Appearance, EmptyStateView.Appearance>
        public var emptyViewAppearance: EmptyStateView.Appearance
        
        @Trackable<Appearance, SearchResultChannelCell.Appearance>
        public var cellAppearance: SearchResultChannelCell.Appearance
        
        @Trackable<Appearance, SeparatorHeaderView.Appearance>
        public var separatorViewAppearance: SeparatorHeaderView.Appearance
        
        // Initializer with all parameters
        public init(
            backgroundColor: UIColor?,
            emptyViewAppearance: EmptyStateView.Appearance,
            cellAppearance: SearchResultChannelCell.Appearance,
            separatorViewAppearance: SeparatorHeaderView.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._emptyViewAppearance = Trackable(value: emptyViewAppearance)
            self._cellAppearance = Trackable(value: cellAppearance)
            self._separatorViewAppearance = Trackable(value: separatorViewAppearance)
        }
        
        // Convenience Initializer with optional parameters
        public init(
            reference: ChannelSearchResultsViewController.Appearance,
            backgroundColor: UIColor? = nil,
            emptyViewAppearance: EmptyStateView.Appearance? = nil,
            cellAppearance: SearchResultChannelCell.Appearance? = nil,
            separatorViewAppearance: SeparatorHeaderView.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._emptyViewAppearance = Trackable(reference: reference, referencePath: \.emptyViewAppearance)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            self._separatorViewAppearance = Trackable(reference: reference, referencePath: \.separatorViewAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let emptyViewAppearance { self.emptyViewAppearance = emptyViewAppearance }
            if let cellAppearance { self.cellAppearance = cellAppearance }
            if let separatorViewAppearance { self.separatorViewAppearance = separatorViewAppearance }
        }
    }
}
