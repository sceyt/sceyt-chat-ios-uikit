//
//  ActionPresentationController.swift
//  Emoji-Custom-Transition
//
//

import UIKit

final public class ActionPresentationController: UIPresentationController {

    public var contentHeight: CGFloat = .zero
    public var messageFromFrame: CGRect = .zero

    public lazy var blurView: UIView = {
        let visualEffect = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
            .withoutAutoresizingMask
        visualEffect.alpha = 0
        return visualEffect
    }()

    public lazy var dimView: UIView = {
        let dimView = UIView().withoutAutoresizingMask
        dimView.alpha = 0
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        return dimView
    }()

    override public func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
    }
    
    override public func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        blurView.frame = containerView?.frame ?? .zero
        dimView.frame = containerView?.frame ?? .zero
    }
    
    override public func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        containerView?.addSubview(blurView)
        containerView?.addSubview(dimView)
        if let presented = presentedView {
            containerView?.addSubview(presented)
        }
        animateWithTransition(targetOpacity: 1)
    }
    
    override public func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        if !completed {
            blurView.removeFromSuperview()
            dimView.removeFromSuperview()
        }
    }
    
    override public func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        animateWithTransition(targetOpacity: 0)
    }
    
    override public func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        if completed {
            blurView.removeFromSuperview()
            dimView.removeFromSuperview()
        }
    }

    private func animateWithTransition(targetOpacity: CGFloat) {
        guard let coordinator = presentedViewController.transitionCoordinator else {
            updateOpacity(to: targetOpacity)
            return
        }
        coordinator.animate { _ in
            self.updateOpacity(to: targetOpacity)
        }
    }

}

private extension ActionPresentationController {

    func updateOpacity(to value: CGFloat) {
        dimView.alpha = value
        blurView.alpha = value * 0.9
    }
    
}
