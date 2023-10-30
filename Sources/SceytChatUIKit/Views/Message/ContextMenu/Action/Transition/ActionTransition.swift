//
//  ActionTransition.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ActionTransition: NSObject, UIViewControllerTransitioningDelegate {
    
    open func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ActionAnimator(duration: 0.13, transitionType: .present)
    }

    open func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ActionAnimator(duration: 0.25, transitionType: .dismiss)
    }

    open func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        let presentationController = ActionPresentationController(presentedViewController: presented, presenting: presenting)
        return presentationController
    }

}
