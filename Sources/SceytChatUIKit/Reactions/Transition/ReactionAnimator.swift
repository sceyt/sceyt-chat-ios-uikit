//
//  ReactionAnimator.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ReactionAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    enum AnimatorType {
        case present
        case dismiss
    }

    private let animatorType: AnimatorType
    private let duration: TimeInterval

    init(animatorType: AnimatorType,
         duration: TimeInterval) {
        self.animatorType = animatorType
        self.duration = duration
    }

    open func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    open func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let animator: UIViewImplicitlyAnimating
        switch animatorType {
        case .present:
            animator = presentAnimation(transitionContext: transitionContext)
        case .dismiss:
            animator = dismissAnimation(transitionContext: transitionContext)
        }
        animator.startAnimation()
    }

    open func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        let animator: UIViewImplicitlyAnimating
        switch animatorType {
        case .present:
            animator = presentAnimation(transitionContext: transitionContext)
        case .dismiss:
            animator = dismissAnimation(transitionContext: transitionContext)
        }
        return animator
    }

    private func presentAnimation(transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        let to = transitionContext.view(forKey: .to)!
        let finalFrame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)
        to.frame = finalFrame.offsetBy(dx: 0, dy: finalFrame.height)
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut) {
            to.frame = finalFrame
        }
        animator.addCompletion { (position) in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        return animator
    }

    private func dismissAnimation(transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        let fromVC = transitionContext.viewController(forKey: .from)!
        let initialFrame = transitionContext.initialFrame(for: fromVC)
        let fromView = transitionContext.view(forKey: .from)
        let duration = transitionDuration(using: transitionContext)
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut) {
            fromView?.frame = initialFrame.offsetBy(dx: .zero, dy: initialFrame.height)
        }
        animator.addCompletion { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
        return animator
    }

}
