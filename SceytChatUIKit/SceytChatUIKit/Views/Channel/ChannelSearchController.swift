//
//  ChannelSearchController.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelSearchController: SearchController {

    override init(searchResultsController: UIViewController?) {
        super.init(searchResultsController: searchResultsController)
        hidesNavigationBarDuringPresentation = true
        isActive = true
        obscuresBackgroundDuringPresentation = false
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesNavigationBarDuringPresentation = true
        isActive = true
        obscuresBackgroundDuringPresentation = false
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    open override func setup() {
        super.setup()
        searchBar.placeholder = L10n.Channel.List.search
    }
    
}
