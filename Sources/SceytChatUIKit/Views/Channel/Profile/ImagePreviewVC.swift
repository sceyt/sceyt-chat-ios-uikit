//
//  ImagePreviewViewController.swift
//  SceytChatUIKit
//
//  Created by Duc on 24/08/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ImagePreviewViewController: ViewController, UIScrollViewDelegate {
    open var viewModel: ChannelAvatarVM!
    
    private var task: Cancellable?
    
    private lazy var scrollView = MediaPreviewerScrollView(contentMode: .scaleAspectFit)
        .withoutAutoresizingMask
    
    override open func setup() {
        super.setup()
        
        task = Components.avatarBuilder.loadAvatar(
            into: scrollView.imageView,
            for: viewModel.channel,
            size: CGSize(width: view.width * SceytChatUIKit.shared.config.displayScale,
                         height: view.height * SceytChatUIKit.shared.config.displayScale),
            preferMemCache: false) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.layout()
                }
            }
        title = viewModel.channel.displayName
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        view.backgroundColor = appearance.backgroundColor
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        view.addSubview(scrollView)
        scrollView.pin(to: view)
    }
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        layout()
    }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        layout()
    }
    
    open func layout() {
        scrollView.updateConstraintsForSize(scrollView.bounds.size)
        scrollView.updateMinMaxZoomScaleForSize(scrollView.bounds.size)
    }
}
