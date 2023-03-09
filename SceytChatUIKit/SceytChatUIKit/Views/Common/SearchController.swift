//
//  SearchController.swift
//  SceytChatUIKit
//

import UIKit

open class SearchController: UISearchController {

    open override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupAppearance()
        setupLayout()
    }
    
    open func setup() {}
    
    open func setupLayout() {
        view.setNeedsLayout()
    }
    
    open func setupAppearance() {
        
    }

}
