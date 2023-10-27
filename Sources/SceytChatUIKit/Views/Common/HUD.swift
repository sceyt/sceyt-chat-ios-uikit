//
//  HUD.swift
//  SceytChatUIKit
//
//  Created by Duc on 12/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public let hud = SCTUIKitComponents.hud

public protocol HUD {
    static func show()
    static func hide()
    static var isLoading: Bool { get set }
}

open class KitHUD: View, HUD {
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
    
    static var hud: KitHUD? { window.subviews.first(where: { $0 is KitHUD }) as? KitHUD }
    
    public static func show() {
        var hud = hud
        if hud == nil {
            hud = KitHUD().withoutAutoresizingMask
        }
        window.addSubview(hud!)
        hud?.pin(to: window)
    }
    
    public static func hide() {
        hud?.removeFromSuperview()
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
        activityIndicator.color = .kitBlue
    }
}
