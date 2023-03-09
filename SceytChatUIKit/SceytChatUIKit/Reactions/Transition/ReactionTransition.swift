//
//  ReactionTransition.swift
//  SceytChatUIKit
//

import UIKit

open class ReactionTransition: NSObject, UIViewControllerTransitioningDelegate {

    private let transitionDriver = ReactionTransitionDriver()
    
    open func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ReactionAnimator(animatorType: .present, duration: 0.3)
    }

    open func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ReactionAnimator(animatorType: .dismiss, duration: 0.3)
    }

    open func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        transitionDriver.link(to: presented)
        let presentationController = ReactionPresentationController(
            presentedViewController: presented,
            presenting: presenting ?? source
        )
        presentationController.transitionDriver = transitionDriver
        return presentationController
        
    }

    public func interactionControllerForPresentation(
        using animator: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        transitionDriver
    }
    
    open func interactionControllerForDismissal(
        using animator: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        transitionDriver
    }

}
