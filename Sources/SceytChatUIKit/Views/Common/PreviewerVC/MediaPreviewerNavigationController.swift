//
//  MediaPreviewerNavigationController.swift
//  SceytChatUIKit
//
//  Created by Duc on 11/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class MediaPreviewerNavigationController: NavigationController, PreviewerTransitionViewControllerConvertible {
    private let mediaPreviewerCarouselVC: MediaPreviewerCarouselVC
    var sourceView: UIImageView? { mediaPreviewerCarouselVC.sourceView }
    var sourceFrameRelativeToWindow: CGRect? { mediaPreviewerCarouselVC.sourceFrameRelativeToWindow }
    var targetView: UIImageView? { mediaPreviewerCarouselVC.targetView }
    
    private let imageViewerPresentationDelegate: ImageViewerTransitionPresentationManager
    
    required public init(_ mediaPreviewerCarouselVC: MediaPreviewerCarouselVC) {
        self.imageViewerPresentationDelegate = ImageViewerTransitionPresentationManager(imageContentMode: mediaPreviewerCarouselVC.imageContentMode)
        self.mediaPreviewerCarouselVC = mediaPreviewerCarouselVC
        super.init(rootViewController: mediaPreviewerCarouselVC)
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
