//
//  ImageCropperViewController.swift
//  SceytChatUIKit
//
//  Created by Duc on 08.10.2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ImageCropperViewController: ViewController {
    public required convenience init(
        onComplete: ((UIImage) -> Void)? = nil,
        onCancel: (() -> Void)? = nil)
    {
        self.init()
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
  
    // MARK: Private properties & IBOutlets

    open lazy var imageView = UIImageView()
    open lazy var mask = UIView().withoutAutoresizingMask
    open lazy var confirmButton = UIButton().withoutAutoresizingMask
    open lazy var cancelButton = UIButton().withoutAutoresizingMask
    open lazy var buttonsView = UIView().withoutAutoresizingMask
  
    open var viewModel: ImageCropperViewModel!
    open var onComplete: ((UIImage) -> Void)?
    open var onCancel: (() -> Void)?
  
    // MARK: Lifecicle

    override public func viewDidLoad() {
        super.viewDidLoad()
        set(image: viewModel.image)
        
        setup()
        setupLayout()
        setupAppearance()
        setupDone()
    }
  
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        clearMask()
        
        if !viewModel.isInitial {
            viewModel.parentFrame = view.frame
            setImageFrame(viewModel.imageInitialFrame)
            viewModel.isInitial = true
        }
        drawMask(by: viewModel.mask, with: .black.withAlphaComponent(0.5))
    }
    
    override open func setup() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch))
        view.addGestureRecognizer(pinch)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan))
        view.addGestureRecognizer(pan)
        
        cancelButton.addTarget(self, action: #selector(onCancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(onConfirmTapped), for: .touchUpInside)
        
        navigationItem.hidesBackButton = true
        title = L10n.ImageCropper.moveAndScale
        
        view.layer.masksToBounds = true
    }
    
    override open func setupLayout() {
        view.addSubview(imageView)
        view.addSubview(mask)
        view.addSubview(buttonsView)
        buttonsView.addSubview(cancelButton)
        buttonsView.addSubview(confirmButton)
        
        mask.pin(to: view)
        buttonsView.pin(to: view, anchors: [.leading, .trailing, .bottom])
        
        cancelButton.pin(to: buttonsView, anchors: [.top, .leading])
        cancelButton.bottomAnchor.pin(to: buttonsView.safeAreaLayoutGuide.bottomAnchor)
        cancelButton.heightAnchor.pin(greaterThanOrEqualToConstant: 44)
        
        confirmButton.pin(to: buttonsView, anchors: [.top, .trailing])
        confirmButton.bottomAnchor.pin(to: buttonsView.safeAreaLayoutGuide.bottomAnchor)
        confirmButton.heightAnchor.pin(greaterThanOrEqualToConstant: 44)
        
        imageView.contentMode = .scaleAspectFit
        
        cancelButton.contentEdgeInsets = .init(top: Layouts.buttonPadding, left: Layouts.buttonPadding, bottom: Layouts.buttonPadding, right: Layouts.buttonPadding)
        confirmButton.contentEdgeInsets = .init(top: Layouts.buttonPadding, left: Layouts.buttonPadding, bottom: Layouts.buttonPadding, right: Layouts.buttonPadding)
    }
    
    override open func setupAppearance() {
        view.backgroundColor = appearance.backgroundColor
        buttonsView.backgroundColor = appearance.buttonBackgroundColor
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: appearance.buttonFont as Any,
            .foregroundColor: appearance.buttonColor as Any,
        ]
        cancelButton.setAttributedTitle(.init(
            string: L10n.Nav.Bar.cancel,
            attributes: attributes), for: [])
        confirmButton.setAttributedTitle(.init(
            string: L10n.Nav.Bar.confirm,
            attributes: attributes), for: [])
    }

    @objc func onCancelTapped(_ sender: UIButton) {
        onCancel?()
    }
  
    @objc func onConfirmTapped(_ sender: UIButton) {
        loader.isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let image = self.viewModel.crop()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                loader.isLoading = false
                self.onComplete?(image)
            }
        }
    }
  
    @objc func onPan(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began:
            setIsUserInteracting(true)
      
        case .changed:
            setImageFrame(viewModel.draggingFrame(for: sender.location(in: sender.view!)))
      
        case .ended:
            setIsUserInteracting(false)
      
        default:
            return
        }
    }
  
    @objc func onPinch(_ sender: UIPinchGestureRecognizer) {
        switch sender.state {
        case .began:
            guard sender.numberOfTouches >= 2 else { return }
            setIsUserInteracting(true)
            viewModel.setStartedPinch()
        case .changed:
            guard sender.numberOfTouches >= 2 else { return }
            setImageFrame(viewModel.scalingFrame(for: sender.scale))
        case .ended, .cancelled:
            setIsUserInteracting(false)
        default:
            return
        }
    }
  
    func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        return sqrt(pow(first.x - second.x, 2) + pow(first.y - second.y, 2))
    }

    func set(image: UIImage) {
        imageView.image = image
    }
  
    func setImageFrame(_ frame: CGRect) {
        imageView.frame = frame
    }
  
    func transformImage(with frame: CGRect) {
        UIView.animate(withDuration: 0.25) {
            self.imageView.frame = frame
        }
    }
  
    func clearMask() {
        mask.layer.mask = nil
        mask.layer.sublayers?.forEach { sublayer in
            sublayer.removeFromSuperlayer()
        }
    }
  
    func drawMask(by path: CGPath, with fillColor: UIColor) {
        let hole = CAShapeLayer()
        hole.frame = mask.bounds
        hole.path = path
        hole.fillRule = CAShapeLayerFillRule.evenOdd
        mask.layer.mask = hole
        mask.backgroundColor = fillColor
    }
  
    func setIsUserInteracting(_ flag: Bool) {
        let alpha = flag ? 0 : 1
        UIView.animate(withDuration: 0.1) {
            self.buttonsView.alpha = CGFloat(alpha)
        }
        viewModel.transformatingFinished()
    }
}

public extension ImageCropperViewController {
    enum Layouts {
        public static var maskPadding: CGFloat = 8
        public static var buttonPadding: CGFloat = 16
    }
}
