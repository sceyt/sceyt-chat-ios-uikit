//
//  ActionTransition.swift
//  Emoji-Custom-Transition
//
//

import UIKit

open class ActionTransition: NSObject, UIViewControllerTransitioningDelegate {
    
    open func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ActionAnimator(duration: 0.8, transitionType: .present)
    }

    open func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ActionAnimator(duration: 0.3, transitionType: .dismiss)
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
