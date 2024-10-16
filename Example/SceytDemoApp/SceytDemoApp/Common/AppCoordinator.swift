//
//  AppCoordinator.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

final class AppCoordinator {
    static let shared = AppCoordinator()
    
    private init() {}
    
    func showAuthFlow() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let authNavController = storyboard.instantiateViewController(withIdentifier: "LandingNavigationController") as? UINavigationController {
            changeRootViewController(to: authNavController)
        }
    }
    
    func showMainFlow() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let tabBarVC = storyboard.instantiateViewController(withIdentifier: "TabBarController") as? TabBarController {
            changeRootViewController(to: tabBarVC)
        }
    }
    
    private func changeRootViewController(to viewController: UIViewController, animated: Bool = true) {
        guard let window = UIApplication.shared.windows.first else {
            return
        }
        window.rootViewController = viewController
        if animated {
            UIView.transition(with: window,
                              duration: 0.5,
                              options: .transitionCrossDissolve,
                              animations: nil,
                              completion: nil)
        }
    }
}
