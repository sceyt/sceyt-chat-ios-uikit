//
//  ActionPresentationController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

final public class ActionPresentationController: UIPresentationController {

    public var contentHeight: CGFloat = .zero
    public var messageFromFrame: CGRect = .zero

    public lazy var blurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: blurEffect)
        view.alpha = .zero
        return view
    }()

    public lazy var dimView: UIView = {
        let dimView = UIView().withoutAutoresizingMask
        dimView.alpha = .zero
        dimView.backgroundColor = appearance.dimColor
        return dimView
    }()
    
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
        blurView.alpha = value
    }
    
}
