//
//  ChannelSearchController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelSearchController: SearchController {
    
    public override required init(searchResultsController: UIViewController?) {
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
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override open func setup() {
        super.setup()
        
        searchBar.placeholder = L10n.Channel.List.search
    }
}
