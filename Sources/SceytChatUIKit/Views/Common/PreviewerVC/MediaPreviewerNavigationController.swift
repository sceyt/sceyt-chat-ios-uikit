//
//  MediaPreviewerNavigationController.swift
//  SceytChatUIKit
//
//  Created by Duc on 11/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class MediaPreviewerNavigationController: NavigationController, PreviewerTransitionViewControllerConvertible {
    private let mediaPreviewerCarouselViewController: MediaPreviewerCarouselViewController
    var sourceView: UIImageView? { mediaPreviewerCarouselViewController.sourceView }
    var sourceFrameRelativeToWindow: CGRect? { mediaPreviewerCarouselViewController.sourceFrameRelativeToWindow }
    var targetView: UIImageView? { mediaPreviewerCarouselViewController.targetView }

    private let imageViewerPresentationDelegate: ImageViewerTransitionPresentationManager?

    required public init(_ mediaPreviewerCarouselViewController: MediaPreviewerCarouselViewController) {
        let viewOnce = mediaPreviewerCarouselViewController.viewOnce
        self.imageViewerPresentationDelegate = viewOnce ? nil : ImageViewerTransitionPresentationManager(imageContentMode: mediaPreviewerCarouselViewController.imageContentMode)
        self.mediaPreviewerCarouselViewController = mediaPreviewerCarouselViewController
        super.init(rootViewController: mediaPreviewerCarouselViewController)

        if !viewOnce {
            transitioningDelegate = imageViewerPresentationDelegate
            modalPresentationStyle = .custom
        } else {
            modalPresentationStyle = .fullScreen
        }
        modalPresentationCapturesStatusBarAppearance = true
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Controls the immersive (full-screen) state of the previewer. When `true` the
    /// navigation bar and the system status bar (clock, battery, etc.) are both hidden;
    /// the user toggles it by tapping the media.
    ///
    /// The navigation bar is driven through `setNavigationBarHidden(_:animated:)` — i.e.
    /// UIKit's own hidden-state bookkeeping — rather than by animating `navigationBar.alpha`.
    /// That matters because hiding the status bar makes UIKit relayout the bar, and a bar
    /// hidden via `alpha` gets restored to full opacity by that relayout, whereas a bar
    /// hidden via `setNavigationBarHidden` stays hidden.
    open var isPreviewStatusBarHidden = false {
        didSet {
            guard oldValue != isPreviewStatusBarHidden else { return }
            setNavigationBarHidden(isPreviewStatusBarHidden, animated: true)
            UIView.animate(withDuration: 0.3) {
                self.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    open override var prefersStatusBarHidden: Bool {
        isPreviewStatusBarHidden
    }

    open override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }

    // Make this navigation controller the single status-bar authority so the
    // overrides above are consulted directly, instead of being forwarded to the
    // top view controller (the page/carousel controller) by UINavigationController.
    open override var childForStatusBarHidden: UIViewController? {
        nil
    }

    open override var childForStatusBarStyle: UIViewController? {
        nil
    }
}
