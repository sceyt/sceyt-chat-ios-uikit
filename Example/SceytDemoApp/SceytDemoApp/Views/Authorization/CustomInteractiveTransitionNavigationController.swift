//
//  CustomInteractiveTransitionNavigationController.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 14.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChatUIKit

public class CustomInteractiveTransitionNavigationController: NavigationController {
    
    var presentationControllerType: UIPresentationController.Type!
    
    override public required init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func setup() {
        super.setup()
        view.clipsToBounds = true
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
}

extension CustomInteractiveTransitionNavigationController: UIViewControllerTransitioningDelegate {
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return presentationControllerType.init(presentedViewController: presented, presenting: presenting)
    }
}
