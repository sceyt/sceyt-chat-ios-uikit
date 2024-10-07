//
//  SearchController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension SearchController: AppearanceProviding {
    
    public static var appearance = Appearance(searchBarAppearance:
            .init(
                reference: SearchBarAppearance.appearance,
                placeholder: L10n.SearchBar.placeholder,
                searchIcon: .searchIcon
            )
    )
    
    public struct Appearance {
        @Trackable<Appearance, SearchBarAppearance.Appearance>
        public var searchBarAppearance: SearchBarAppearance.Appearance
        
        // Initializer with custom searchBarAppearance
        public init(searchBarAppearance: SearchBarAppearance.Appearance) {
            self._searchBarAppearance = Trackable(value: searchBarAppearance)
        }
        
        public init(
            reference: SearchController.Appearance,
            searchBarAppearance: SearchBarAppearance.Appearance? = nil
        ) {
            self._searchBarAppearance = Trackable(reference: reference, referencePath: \.searchBarAppearance)
            if let searchBarAppearance { self.searchBarAppearance = searchBarAppearance }
        }
    }
}
