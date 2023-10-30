//
//  PreviewerNavigationController.swift
//  SceytChatUIKit
//
//  Created by Duc on 11/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class PreviewerNavigationController: NavigationController, PreviewerTransitionViewControllerConvertible {
    private let previewerCarouselVC: PreviewerCarouselVC
    var sourceView: UIImageView? { previewerCarouselVC.sourceView }
    var sourceFrameRelativeToWindow: CGRect? { previewerCarouselVC.sourceFrameRelativeToWindow }
    var targetView: UIImageView? { previewerCarouselVC.targetView }
    
    private let imageViewerPresentationDelegate: ImageViewerTransitionPresentationManager
    
    required public init(_ previewerCarouselVC: PreviewerCarouselVC) {
        self.imageViewerPresentationDelegate = ImageViewerTransitionPresentationManager(imageContentMode: previewerCarouselVC.imageContentMode)
        self.previewerCarouselVC = previewerCarouselVC
        super.init(rootViewController: previewerCarouselVC)
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
