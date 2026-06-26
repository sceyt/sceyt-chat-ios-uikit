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

    private var isObservingNavBarAlpha = false

    open override func viewDidLoad() {
        super.viewDidLoad()
        // Observe the navigation bar's alpha so we can re-assert the hidden state the
        // instant UIKit raises it (see enforceHiddenNavBarIfNeeded()).
        navigationBar.addObserver(self, forKeyPath: "alpha", options: [.new], context: nil)
        isObservingNavBarAlpha = true
    }

    deinit {
        if isObservingNavBarAlpha {
            navigationBar.removeObserver(self, forKeyPath: "alpha")
        }
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "alpha" else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        enforceHiddenNavBarIfNeeded()
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        enforceHiddenNavBarIfNeeded()
    }

    /// UINavigationController re-asserts `navigationBar.alpha = 1` shortly after a
    /// status-bar visibility change (the bar and the status bar share this controller).
    /// While we're in immersive/hidden mode, snap the alpha back to 0 the instant it's
    /// raised — synchronously, from inside the KVO callback — so the bar never renders
    /// back into view. We only ever pin *down* to 0 while hidden, so the tap-to-show
    /// animation and the pan-to-dismiss partial fade are left untouched.
    private func enforceHiddenNavBarIfNeeded() {
        guard isPreviewStatusBarHidden, navigationBar.alpha != 0 else { return }
        navigationBar.alpha = 0
    }

    /// Controls whether the system status bar (clock, battery, etc.) is hidden.
    /// Toggled together with the navigation bar / player controls when the user
    /// taps the media to enter "immersive" full-screen viewing.
    open var isPreviewStatusBarHidden = false {
        didSet {
            guard oldValue != isPreviewStatusBarHidden else { return }
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
