//
//  LoaderView.swift
//  SceytChatUIKit
//
//  Created by Duc on 12/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public let loader = Components.loader

public protocol LoaderRepresentable {
    static func show()
    static func hide()
    static var isLoading: Bool { get set }
}

open class LoaderView: View, LoaderRepresentable {
    public static var isLoading: Bool = false {
        didSet {
            if isLoading {
                show()
            } else {
                hide()
            }
        }
    }
    
    static var window: UIWindow { UIApplication.shared.windows.first ?? UIWindow() }
    
    static var loader: LoaderView? { window.subviews.first(where: { $0 is LoaderView }) as? LoaderView }
    
    public static func show() {
        DispatchQueue.main.async {
            var loader = loader
            if loader == nil {
                loader = LoaderView().withoutAutoresizingMask
            }
            window.addSubview(loader!)
            loader?.pin(to: window)
        }
    }
    
    public static func hide() {
        DispatchQueue.main.async {
            loader?.removeFromSuperview()
        }
    }
    
    open lazy var activityIndicator = UIActivityIndicatorView(style: .large)
        .withoutAutoresizingMask
    
    override open func setup() {
        super.setup()
        
        activityIndicator.startAnimating()
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        addSubview(activityIndicator)
        activityIndicator.pin(to: self, anchors: [.centerX, .centerY])
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = .black.withAlphaComponent(0.5)
        activityIndicator.color = .accent
    }
}
