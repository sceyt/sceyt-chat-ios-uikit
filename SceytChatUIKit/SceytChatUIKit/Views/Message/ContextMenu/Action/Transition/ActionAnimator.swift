//
//  ActionAnimator.swift
//  Emoji-Custom-Transition
//
//

import UIKit

final public class ActionAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    public let duration: TimeInterval
    public let transitionType: TransitionType
    
    public let emojiSnapshotTag = 1000
    
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
        print("[ANIMATION WARNING] Seems like this view is not in views hierarchy\n\(view)\nOriginal frame returned")
        return view.frame
    }

}

private extension ActionAnimator {
    
    func animatePresentation(context: UIViewControllerContextTransitioning) {
        guard let toVc = context.viewController(forKey: .to) as? ActionController else {
            context.completeTransition(false)
            return
        }
        
        toVc.loadViewIfNeeded()
        toVc.view.layoutIfNeeded()
        
        let snapshotFinalFrame = toVc.snapshot?.frame ?? .zero
        
        toVc.contextView?.isHidden = true
        toVc.snapshot?.frame = toVc.contextView?.superview?.convert(
            toVc.contextView?.frame ?? .zero,
            to: toVc.view
        ) ?? .zero
        
        toVc.view.frame = context.containerView.bounds
        
        let duration = transitionDuration(using: context)
        
        toVc.emojiController.setupForAnimation()
        toVc.menuContainer.alpha = 0
        toVc.menuContainer.transform = .identity.scaledBy(x: 0.6, y: 0.6)
        
        UIView.animateKeyframes(withDuration: duration, delay: 0) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.15) {
                toVc.snapshot?.frame = snapshotFinalFrame
            }
            UIView.addKeyframe(withRelativeStartTime: 0.15, relativeDuration: 0.1) {
                toVc.menuContainer.alpha = 1
                toVc.menuContainer.transform = .identity
            }
            toVc.emojiController.animateShow(start: 0.25, relativeDuration: 0.75)
        } completion: { _ in
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
    
    func animateDismissal(context: UIViewControllerContextTransitioning) {
        guard let toVc = context.viewController(forKey: .to),
              let fromVc = context.viewController(forKey: .from) as? ActionController else {
            context.completeTransition(false)
            return
        }
        
        let duration = transitionDuration(using: context)
        
        let snapshotFinalFrame = fromVc.contextView?.superview?.convert(
            fromVc.contextView?.frame ?? .zero,
            to: toVc.view
        ) ?? .zero
        
        UIView.animateKeyframes(withDuration: duration, delay: 0) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2) {
                fromVc.emojiContainer.alpha = 0
            }
            UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.2) {
                fromVc.menuContainer.alpha = 0
            }
            UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.6) {
                fromVc.snapshot?.frame = snapshotFinalFrame
            }
        } completion: { _ in
            fromVc.contextView?.isHidden = false
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
