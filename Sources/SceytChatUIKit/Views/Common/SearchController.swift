//
//  SearchController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class SearchController: UISearchController {
    public override init(searchResultsController: UIViewController?) {
        super.init(searchResultsController: searchResultsController)
        setupAppearance()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupAppearance()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }
    
    open var placeholder: String? {
        get { searchBar.placeholder }
        set {
            if let newValue {
                searchBar.searchTextField.attributedPlaceholder = .init(string: newValue, attributes: [
                    .font: appearance.font ?? Fonts.regular.withSize(16),
                    .foregroundColor: appearance.placeholderColor ?? .init(light: 0xA0A1B0, dark: 0x76787A)
                ])
            } else {
                searchBar.searchTextField.attributedText = nil
            }
        }
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupAppearance()
        setupLayout()
    }

    open func setup() {
        placeholder = L10n.SearchBar.placeholder
    }

    open func setupLayout() {
        view.setNeedsLayout()
    }

    open func setupAppearance() {
        searchBar.backgroundImage = .init()
        searchBar.backgroundColor = appearance.backgroundColor
        searchBar.setSearchFieldBackgroundImage(appearance.backgroundImage?.imageAsset?.image(with: .current), for: [])
        searchBar.setImage(.searchIcon, for: .search, state: [])
        searchBar.searchTextField.layer.cornerRadius = Layouts.cornerRadius
        searchBar.searchTextField.clipsToBounds = true
        searchBar.searchTextField.font = appearance.font
        searchBar.searchTextField.textColor = appearance.textColor
        searchBar.searchTextPositionAdjustment = UIOffset(horizontal: 4, vertical: 0)
    }

    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        setupAppearance()
    }
}

public extension SearchController {
    enum Layouts {
        public static var cornerRadius: CGFloat = 18
    }
}
