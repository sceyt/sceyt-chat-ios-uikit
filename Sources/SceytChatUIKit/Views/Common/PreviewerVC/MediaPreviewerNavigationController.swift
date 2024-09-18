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
    
    private let imageViewerPresentationDelegate: ImageViewerTransitionPresentationManager
    
    required public init(_ mediaPreviewerCarouselViewController: MediaPreviewerCarouselViewController) {
        self.imageViewerPresentationDelegate = ImageViewerTransitionPresentationManager(imageContentMode: mediaPreviewerCarouselViewController.imageContentMode)
        self.mediaPreviewerCarouselViewController = mediaPreviewerCarouselViewController
        super.init(rootViewController: mediaPreviewerCarouselViewController)
        transitioningDelegate = imageViewerPresentationDelegate
        modalPresentationStyle = .custom
        modalPresentationCapturesStatusBarAppearance = true
        navigationBar.isTranslucent = true
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.shadowImage = UIImage()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
}
