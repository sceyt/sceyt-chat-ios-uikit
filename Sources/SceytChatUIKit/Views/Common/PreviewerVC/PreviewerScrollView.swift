//
//  PreviewerScrollView.swift
//  SceytChatUIKit
//
//  Created by Duc on 07/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class PreviewerScrollView: UIScrollView, Configurable, UIScrollViewDelegate {
    open lazy var imageView = {
        $0.contentMode = .scaleAspectFit
        return $0.withoutAutoresizingMask
    }(UIImageView())
    
    private var topConstraint: NSLayoutConstraint!
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var bottomConstraint: NSLayoutConstraint!
    
    private var maxZoomScale: CGFloat = 1.0
    
    open lazy var pinchRecognizer = UITapGestureRecognizer(
        target: self, action: #selector(onPinch(_:)))
    
    open lazy var doubleTapRecognizer = UITapGestureRecognizer(
        target: self, action: #selector(onDoubleTap(_:)))
    
    override open var delegate: UIScrollViewDelegate? {
        get { super.delegate }
        set {
            if newValue == nil || newValue === self {
                super.delegate = newValue
            } else {
                fatalError("PreviewerScrollView does support setting custom delegate")
            }
        }
    }
    
    public init(contentMode: UIView.ContentMode) {
        super.init(frame: .zero)
        imageView.contentMode = contentMode
        
        setup()
        setupLayout()
        setupAppearance()
        setupDone()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setup()
        setupLayout()
        setupAppearance()
        setupDone()
    }
    
    public func setup() {
        delegate = self
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        
        addGestureRecognizers()
    }
    
    public func setupLayout() {
        addSubview(imageView)
        topConstraint = imageView.topAnchor.pin(to: topAnchor)
        leadingConstraint = imageView.leadingAnchor.pin(to: leadingAnchor)
        trailingConstraint = imageView.trailingAnchor.pin(to: trailingAnchor)
        bottomConstraint = imageView.bottomAnchor.pin(to: bottomAnchor)
    }
    
    public func setupAppearance() {
        backgroundColor = .clear
    }
    
    public func setupDone() {}
    
    // MARK: Add Gesture Recognizers
    
    open func addGestureRecognizers() {
        pinchRecognizer.numberOfTapsRequired = 1
        pinchRecognizer.numberOfTouchesRequired = 2
        addGestureRecognizer(pinchRecognizer)
        
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        addGestureRecognizer(doubleTapRecognizer)
    }
    
    @objc
    open func onPinch(_ recognizer: UITapGestureRecognizer) {
        var newZoomScale = zoomScale / 1.5
        newZoomScale = max(newZoomScale, minimumZoomScale)
        setZoomScale(newZoomScale, animated: true)
    }
    
    @objc
    open func onDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let pointInView = recognizer.location(in: imageView)
        zoomInOrOut(at: pointInView)
    }
    
    // MARK: Adjusting the dimensions
    
    open func updateMinMaxZoomScaleForSize(_ size: CGSize) {
        let targetSize = imageView.bounds.size
        if targetSize.width == 0 || targetSize.height == 0 {
            return
        }
        
        let minScale = min(
            size.width / targetSize.width,
            size.height / targetSize.height)
        let maxScale = max(
            (size.width + 1.0) / targetSize.width,
            (size.height + 1.0) / targetSize.height)
        
        minimumZoomScale = minScale
        zoomScale = minScale
        maxZoomScale = maxScale
        maximumZoomScale = maxZoomScale * 1.1
    }
    
    open func zoomInOrOut(at point: CGPoint) {
        let newZoomScale = zoomScale == minimumZoomScale
            ? maxZoomScale : minimumZoomScale
        let size = bounds.size
        let w = size.width / newZoomScale
        let h = size.height / newZoomScale
        let x = point.x - (w * 0.5)
        let y = point.y - (h * 0.5)
        let rect = CGRect(x: x, y: y, width: w, height: h)
        zoom(to: rect, animated: true)
    }
    
    open func updateConstraintsForSize(_ size: CGSize) {
        let yOffset = max(0, (size.height - imageView.frame.height) / 2)
        topConstraint.constant = yOffset
        bottomConstraint.constant = yOffset
        
        let xOffset = max(0, (size.width - imageView.frame.width) / 2)
        leadingConstraint.constant = xOffset
        trailingConstraint.constant = xOffset
        layoutIfNeeded()
    }
    
    // MARK: ScrollView delegate
    
    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    open func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateConstraintsForSize(bounds.size)
    }
}
