//
//  ActionAnimator.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

final public class ActionAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    public let duration: TimeInterval
    public let transitionType: TransitionType
        
    required public init(
        duration: TimeInterval,
        transitionType: TransitionType) {
        self.duration = duration
        self.transitionType = transitionType
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        switch transitionType {
        case .present:
            animatePresentation(context: transitionContext)
        case .dismiss:
            animateDismissal(context: transitionContext)
        }
    }

    public func frameOfViewInWindowsCoordinateSystem(_ view: UIView) -> CGRect {
        if let superview = view.superview {
            return superview.convert(view.frame, to: nil)
        }
        logger.debug("[ANIMATION WARNING] Seems like this view is not in views hierarchy\n\(view)\nOriginal frame returned")
        return view.frame
    }

}

private extension ActionAnimator {
    
    func animatePresentation(context: UIViewControllerContextTransitioning) {
        guard let toViewController = context.viewController(forKey: .to) as? ActionController else {
            context.completeTransition(false)
            return
        }
        toViewController.loadViewIfNeeded()
        toViewController.view.layoutIfNeeded()
        
        let snapshotFinalFrame = toViewController.snapshot?.frame ?? .zero
            
        toViewController.contextView?.alpha = 0
        toViewController.snapshot?.frame = toViewController.contextView?.superview?.convert(
            toViewController.contextView?.frame ?? .zero,
            to: toViewController.view
        ) ?? .zero
        toViewController.snapshot?.transform = SceytChatUIKit.shared.config.messageBubbleTransformScale

        toViewController.view.frame = context.containerView.bounds
        
        let duration = transitionDuration(using: context)
        
        toViewController.emojiController.setupForAnimation()
        toViewController.menuContainer.alpha = 0
        toViewController.menuContainer.transform = .identity.scaledBy(x: 0.6, y: 0.6)
        
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: [.allowUserInteraction]) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1.0) {
                toViewController.snapshot?.transform = .identity
                toViewController.snapshot?.frame = snapshotFinalFrame
            }
            UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                toViewController.menuContainer.alpha = 1
                toViewController.menuContainer.transform = .identity
            }
        } completion: { _ in
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
    
    func animateDismissal(context: UIViewControllerContextTransitioning) {
        guard let toViewController = context.viewController(forKey: .to),
              let fromViewController = context.viewController(forKey: .from) as? ActionController else {
            context.completeTransition(false)
            return
        }
        
        let duration = transitionDuration(using: context)
        
        let snapshotFinalFrame = fromViewController.contextView?.superview?.convert(
            fromViewController.contextView?.frame ?? .zero,
            to: toViewController.view
        ) ?? .zero
        let snapshotDif = (fromViewController.snapshot?.frame.origin.y ?? .zero) - snapshotFinalFrame.origin.y
        
        let mAnchorPoint: CGPoint
        let eAnchorPoint: CGPoint
        let alignment = fromViewController.horizontalAlignment
        switch alignment {
        case .leading:
            mAnchorPoint = .init(x: 0.8, y: 0.8)
            eAnchorPoint = .init(x: 0.55, y: 0.2)
        case .center:
            mAnchorPoint = .init(x: 0.5, y: 0.8)
            eAnchorPoint = .init(x: 0.5, y: 0.2)
        case .trailing:
            mAnchorPoint = .init(x: 0.2, y: 0.8)
            eAnchorPoint = .init(x: 0.45, y: 0.2)
        }
        
        UIView.animateKeyframes(withDuration: duration, delay: 0) {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 1) {
                fromViewController.emojiContainer.alpha = 0
                if fromViewController.emojiContainerAtTheTop == false {
                    fromViewController.emojiContainer.layer.anchorPoint = eAnchorPoint
                    fromViewController.emojiContainer.frame.origin.y -= snapshotDif
                    fromViewController.emojiContainer.transform = .init(scaleX: 0.8, y: 0.8)
                }
            }
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 1) {
                fromViewController.menuContainer.alpha = 0
                fromViewController.menuContainer.transform = .init(scaleX: 0.6, y: 0.6)
                fromViewController.menuContainer.frame.origin.y -= snapshotDif
                fromViewController.menuContainer.layer.anchorPoint = mAnchorPoint
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                fromViewController.snapshot?.frame = snapshotFinalFrame
            }
        } completion: { _ in
            fromViewController.contextView?.alpha = 1
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
    
}

public extension ActionAnimator {
    
    enum TransitionType {
        case present
        case dismiss
    }
    
}
