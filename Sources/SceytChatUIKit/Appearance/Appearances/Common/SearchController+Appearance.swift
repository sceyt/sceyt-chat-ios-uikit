//
//  SearchController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension SearchController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var searchBarAppearance: SearchBarAppearance = .init(
            placeholder: L10n.SearchBar.placeholder,
            searchIcon: .searchIcon
        )
        
        // Initializer with custom searchBarAppearance
        public init(
            searchBarAppearance: SearchBarAppearance = .init(
                placeholder: L10n.SearchBar.placeholder,
                searchIcon: .searchIcon
            )
        ) {
            self.searchBarAppearance = searchBarAppearance
        }
    }
}
