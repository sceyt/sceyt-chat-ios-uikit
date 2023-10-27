//
//  PreviewerTransitionViewControllerConvertible.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

protocol PreviewerTransitionViewControllerConvertible {
    // The source view
    var sourceView: UIImageView? { get }
    var sourceFrameRelativeToWindow: CGRect? { get }

    // The final view
    var targetView: UIImageView? { get }
}

final class ImageViewerTransitionPresentationAnimator: NSObject {
    let isPresenting: Bool
    let imageContentMode: UIView.ContentMode
    
    var observation: NSKeyValueObservation?
    
    init(isPresenting: Bool, imageContentMode: UIView.ContentMode) {
        self.isPresenting = isPresenting
        self.imageContentMode = imageContentMode
        super.init()
    }
}

// MARK: - UIViewControllerAnimatedTransitioning

extension ImageViewerTransitionPresentationAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?)
        -> TimeInterval
    {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewControllerKey = isPresenting ? .to : .from
        guard let controller = transitionContext.viewController(forKey: key)
        else { return }
        
        let animationDuration = transitionDuration(using: transitionContext)
        if isPresenting {
            presentAnimation(
                transitionView: transitionContext.containerView,
                controller: controller,
                duration: animationDuration)
            { finished in
                transitionContext.completeTransition(finished)
            }
            
        } else {
            dismissAnimation(
                transitionView: transitionContext.containerView,
                controller: controller,
                duration: animationDuration)
            { finished in
                transitionContext.completeTransition(finished)
            }
        }
    }
    
    private func createDummyImageView(frame: CGRect, image: UIImage? = nil)
        -> PreviewerImageView
    {
        let dummyImageView = PreviewerImageView(image: image)
        dummyImageView.clipsToBounds = true
        dummyImageView.contentMode = imageContentMode
        dummyImageView.alpha = 1.0
        dummyImageView.frame = frame
        return dummyImageView
    }
    
    private func presentAnimation(
        transitionView: UIView,
        controller: UIViewController,
        duration: TimeInterval,
        completed: @escaping ((Bool) -> Void))
    {
        guard
            let transitionVC = controller as? PreviewerTransitionViewControllerConvertible,
            let sourceView = transitionVC.sourceView
        else { return }
            
        sourceView.alpha = 0.0
        controller.view.alpha = 0.0
            
        transitionView.addSubview(controller.view)
        transitionVC.targetView?.alpha = 0.0
        transitionVC.targetView?.tintColor = sourceView.tintColor
            
        let dummyImageView = createDummyImageView(
            frame: transitionVC.sourceFrameRelativeToWindow ?? sourceView.frameRelativeToWindow(),
            image: sourceView.image)
        dummyImageView.contentMode = sourceView.contentMode
        dummyImageView.tintColor = sourceView.tintColor
        transitionView.addSubview(dummyImageView)
            
        UIView.animate(withDuration: duration, animations: { [weak self] in
            guard let self else { return }
            dummyImageView.frame = UIScreen.main.bounds
            dummyImageView.contentMode = self.imageContentMode
            controller.view.alpha = 1.0
        }) { [weak self] finished in
            self?.observation = transitionVC.targetView?.observe(\.image, options: [.new, .initial]) { _, _ in
                transitionVC.targetView?.alpha = 1.0
                dummyImageView.alpha = 0.0
                dummyImageView.removeFromSuperview()
                completed(finished)
            }
        }
    }
    
    private func dismissAnimation(
        transitionView: UIView,
        controller: UIViewController,
        duration: TimeInterval,
        completed: @escaping ((Bool) -> Void))
    {
        guard
            let transitionVC = controller as? PreviewerTransitionViewControllerConvertible
        else { return }
            
        let sourceView = transitionVC.sourceView
        let targetView = transitionVC.targetView
        let sourceFrameRelativeToWindow = transitionVC.sourceFrameRelativeToWindow
            
        let dummyImageView = createDummyImageView(
            frame: targetView?.frameRelativeToWindow() ?? UIScreen.main.bounds,
            image: targetView?.image)
        dummyImageView.contentMode = targetView?.contentMode ?? .scaleAspectFit
        dummyImageView.tintColor = sourceView?.tintColor
        transitionView.addSubview(dummyImageView)
        targetView?.isHidden = true
            
        controller.view.alpha = 1.0
        UIView.animate(withDuration: duration, animations: {
            if let sourceView = sourceView {
                // return to original position
                dummyImageView.frame = sourceFrameRelativeToWindow ?? sourceView.frameRelativeToWindow()
                dummyImageView.layer.cornerRadius = sourceView.layer.cornerRadius
                dummyImageView.contentMode = sourceView.contentMode
            } else {
                // just disappear
                dummyImageView.alpha = 0.0
            }
            controller.view.alpha = 0.0
        }) { finished in
            sourceView?.alpha = 1.0
            controller.view.removeFromSuperview()
            completed(finished)
        }
    }
}

final class ImageViewerTransitionPresentationController: UIPresentationController {
    override var frameOfPresentedViewInContainerView: CGRect {
        var frame: CGRect = .zero
        frame.size = size(forChildContentContainer: presentedViewController,
                          withParentContainerSize: containerView!.bounds.size)
        return frame
    }
    
    override func containerViewWillLayoutSubviews() {
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

final class ImageViewerTransitionPresentationManager: NSObject {
    private let imageContentMode: UIView.ContentMode
    
    public init(imageContentMode: UIView.ContentMode) {
        self.imageContentMode = imageContentMode
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension ImageViewerTransitionPresentationManager: UIViewControllerTransitioningDelegate {
    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController) -> UIPresentationController?
    {
        let presentationController = ImageViewerTransitionPresentationController(
            presentedViewController: presented,
            presenting: presenting)
        return presentationController
    }
    
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        return ImageViewerTransitionPresentationAnimator(isPresenting: true, imageContentMode: imageContentMode)
    }
    
    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        return ImageViewerTransitionPresentationAnimator(isPresenting: false, imageContentMode: imageContentMode)
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension ImageViewerTransitionPresentationManager: UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return .none
    }
    
    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController?
    {
        return nil
    }
}
