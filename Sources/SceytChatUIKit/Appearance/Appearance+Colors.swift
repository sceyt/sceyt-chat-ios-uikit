//
//  Appearance+Colors.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension UIColor {
    
    static var primaryAccent: UIColor { Components.theme.primaryAccent }
    static var secondaryAccent: UIColor { Components.theme.secondaryAccent }
    static var tertiaryAccent: UIColor { Components.theme.tertiaryAccent }
    static var quaternaryAccent: UIColor { Components.theme.quaternaryAccent }
    static var quinaryAccent: UIColor { Components.theme.quinaryAccent }
    
    static var surface1: UIColor { Components.theme.surface1 }
    static var surface2: UIColor { Components.theme.surface2 }
    static var surface3: UIColor { Components.theme.surface3 }
    
    static var background: UIColor { Components.theme.background }
    static var backgroundMuted: UIColor { Components.theme.backgroundMuted }
    static var backgroundSections: UIColor { Components.theme.backgroundSections }
    static var backgroundDark: UIColor { Components.theme.backgroundDark }
    static var borders: UIColor { Components.theme.borders }
    static var iconInactive: UIColor { Components.theme.iconInactive }
    static var iconSecondary: UIColor { Components.theme.iconSecondary }
    static var overlayBackground1: UIColor { Components.theme.overlayBackground1 }
    static var overlayBackground2: UIColor { Components.theme.overlayBackground2 }
    
    static var primaryText: UIColor { Components.theme.primaryText }
    static var secondaryText: UIColor { Components.theme.secondaryText }
    static var footnoteText: UIColor { Components.theme.footnoteText }
    static var textOnPrimary: UIColor { Components.theme.textOnPrimary }
    
    static var bubbleOutgoing: UIColor { Components.theme.bubbleOutgoing }
    static var bubbleOutgoingX: UIColor { Components.theme.bubbleOutgoingX }
    static var bubbleIncoming: UIColor { Components.theme.bubbleIncoming }
    static var bubbleIncomingX: UIColor { Components.theme.bubbleIncomingX }
    
    static var stateError: UIColor { Components.theme.stateError }
    static var stateSuccess: UIColor { Components.theme.stateSuccess }
    static var stateAttention: UIColor { Components.theme.stateAttention }
    
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
            self.init(cgColor: light.cgColor)
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
