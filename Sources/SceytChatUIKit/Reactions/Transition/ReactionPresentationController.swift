//
//  ReactionPresentationController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ReactionPresentationController: UIPresentationController {
    open lazy var dimView: UIView = {
        let dimView = UIView()
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.alpha = 0
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(onDimmTapped))
        dimView.addGestureRecognizer(tapRecognizer)
        return dimView
    }()

    open var transitionDriver: ReactionTransitionDriver!
    open var heightRatio: CGFloat = 360 / 812

    override open var shouldPresentInFullscreen: Bool {
        return false
    }
    
    override open var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        
        let bounds = containerView.bounds
        let height = heightRatio * bounds.height
        return CGRect(
            x: 0,
            y: bounds.height - height,
            width: bounds.width,
            height: height
        )
    }
    
    override open func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        dimView.frame = containerView?.frame ?? .zero
    }
    
    override open func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        dimView.backgroundColor = .overlayBackground1
        containerView?.addSubview(dimView)
        if let presented = presentedView {
            containerView?.addSubview(presented)
        }
        animateWithTransition { [unowned self] in
            dimView.alpha = 1
        }
    }
    
    override open func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        if !completed {
            dimView.removeFromSuperview()
        } else {
            transitionDriver.direction = .dismiss
        }
    }
    
    override open func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        animateWithTransition { [unowned self] in
            dimView.alpha = 0
        }
    }
    
    override open func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        if completed {
            dimView.removeFromSuperview()
        }
    }
    
    private func animateWithTransition(handler: @escaping () -> Void) {
        guard let coordinator = presentedViewController.transitionCoordinator else {
            handler()
            return
        }
        coordinator.animate { _ in
            handler()
        }
    }
    
    @objc
    private func onDimmTapped() {
        presentedViewController.dismiss(animated: true)
    }
}
