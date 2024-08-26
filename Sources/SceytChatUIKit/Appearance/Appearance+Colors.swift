//
//  Appearance+Colors.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension UIColor {
    
    static var primaryAccent: UIColor { SceytChatUIKitTheme.primaryAccent }
    static var secondaryAccent: UIColor { SceytChatUIKitTheme.secondaryAccent }
    static var tertiaryAccent: UIColor { SceytChatUIKitTheme.tertiaryAccent }
    static var quaternaryAccent: UIColor { SceytChatUIKitTheme.quaternaryAccent }
    static var quinaryAccent: UIColor { SceytChatUIKitTheme.quinaryAccent }
    
    static var surface1: UIColor { SceytChatUIKitTheme.surface1 }
    static var surface2: UIColor { SceytChatUIKitTheme.surface2 }
    static var surface3: UIColor { SceytChatUIKitTheme.surface3 }
    
    static var background: UIColor { SceytChatUIKitTheme.background }
    static var borders: UIColor { SceytChatUIKitTheme.borders }
    static var iconInactive: UIColor { SceytChatUIKitTheme.iconInactive }
    static var iconSecondary: UIColor { SceytChatUIKitTheme.iconSecondary }
    static var overlayBackground50: UIColor { SceytChatUIKitTheme.overlayBackground50 }
    static var overlayBackground40: UIColor { SceytChatUIKitTheme.overlayBackground40 }
    
    static var primaryText: UIColor { SceytChatUIKitTheme.primaryText }
    static var secondaryText: UIColor { SceytChatUIKitTheme.secondaryText }
    static var footnoteText: UIColor { SceytChatUIKitTheme.footnoteText }
    static var textOnPrimary: UIColor { SceytChatUIKitTheme.textOnPrimary }
    
    static var bubbleOutgoing: UIColor { SceytChatUIKitTheme.bubbleOutgoing }
    static var bubbleOutgoingX: UIColor { SceytChatUIKitTheme.bubbleOutgoingX }
    static var bubbleIncoming: UIColor { SceytChatUIKitTheme.bubbleIncoming }
    static var bubbleIncomingX: UIColor { SceytChatUIKitTheme.bubbleIncomingX }
    
    static var stateError: UIColor { SceytChatUIKitTheme.stateError }
    static var stateSuccess: UIColor { SceytChatUIKitTheme.stateSuccess }
    static var stateAttention: UIColor { SceytChatUIKitTheme.stateAttention }
    
    public static var initialColors: [UIColor] = [ .primaryAccent,
                                                   .secondaryAccent,
                                                   .tertiaryAccent,
                                                   .quaternaryAccent,
                                                   .quinaryAccent ]
    
    static func initial(title: String) -> UIColor {
        initialColors[abs(title.hash) % initialColors.count]
    }
}

public extension UIColor {
    
    convenience init(light: String, dark: String) {
        if #available(iOS 13.0, *) {
            self.init { $0.userInterfaceStyle == .dark ? .init(hex: dark) : .init(hex: light) }
        } else {
            self.init(hex: light)
        }
    }
    
    convenience init(light: Int, dark: Int) {
        if #available(iOS 13.0, *) {
            self.init { $0.userInterfaceStyle == .dark ? .init(rgb: dark) : .init(rgb: light) }
        } else {
            self.init(rgb: light)
        }
    }
    
    convenience init(light: UIColor, dark: UIColor) {
        if #available(iOS 13.0, *) {
            self.init { $0.userInterfaceStyle == .dark ? dark : light }
        } else {
            self.init(red: 0, green: 0, blue: 0, alpha: 0)
        }
    }
    
}

public extension UIColor {
    
    convenience init(hex: String, alpha: CGFloat = 1) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "#"))))
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        self.init(rgb: Int(color), alpha: alpha)
    }
    
    convenience init(rgb: Int, alpha: CGFloat = 1) {
        self.init(red: CGFloat(rgb >> 16 & 0xFF) / 255.0,
                  green: CGFloat(rgb >> 8 & 0xFF) / 255.0,
                  blue: CGFloat(rgb & 0xFF) / 255.0,
                  alpha: alpha)
    }
}
