//
//  SplashViewController.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 14.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

class SplashViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if SceytChatUIKit.shared.currentUserId != nil {
            AppCoordinator.shared.showMainFlow()
        } else {
            AppCoordinator.shared.showAuthFlow()
        }
    }
}
