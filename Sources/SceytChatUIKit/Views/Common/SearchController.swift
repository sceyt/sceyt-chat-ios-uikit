//
//  SearchController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class SearchController: UISearchController {
    
    public override required init(searchResultsController: UIViewController?) {
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
                searchBar.searchTextField.attributedPlaceholder = .init(string: newValue,
                                                                        attributes: [
                    .font: appearance.searchBarAppearance.placeholderAppearance.font,
                    .foregroundColor: appearance.searchBarAppearance.placeholderAppearance.foregroundColor
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
        placeholder = appearance.searchBarAppearance.placeholder
    }

    open func setupLayout() {
        view.setNeedsLayout()
    }

    open func setupAppearance() {
        searchBar.backgroundImage = .init()
        searchBar.backgroundColor = appearance.searchBarAppearance.backgroundColor
        searchBar.setImage(appearance.searchBarAppearance.searchIcon, for: .search, state: [])
        searchBar.searchTextField.layer.cornerRadius = appearance.searchBarAppearance.cornerRadius
        searchBar.searchTextField.layer.cornerCurve = appearance.searchBarAppearance.cornerCurve
        searchBar.searchTextField.layer.borderWidth = appearance.searchBarAppearance.borderWidth
        searchBar.searchTextField.layer.borderColor = appearance.searchBarAppearance.borderColor
        searchBar.searchTextField.clipsToBounds = true
        searchBar.searchTextField.font = appearance.searchBarAppearance.labelAppearance.font
        searchBar.searchTextField.textColor = appearance.searchBarAppearance.labelAppearance.foregroundColor
        searchBar.searchTextPositionAdjustment = UIOffset(horizontal: 4, vertical: 0)
        searchBar.tintColor = appearance.searchBarAppearance.tintColor
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
