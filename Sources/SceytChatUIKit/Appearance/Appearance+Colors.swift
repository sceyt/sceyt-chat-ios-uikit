//
//  Appearance+Colors.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension UIColor {
    
    static var primaryAccent: UIColor { SceytChatUIKit.shared.theme.primaryAccent }
    static var secondaryAccent: UIColor { SceytChatUIKit.shared.theme.secondaryAccent }
    static var tertiaryAccent: UIColor { SceytChatUIKit.shared.theme.tertiaryAccent }
    static var quaternaryAccent: UIColor { SceytChatUIKit.shared.theme.quaternaryAccent }
    static var quinaryAccent: UIColor { SceytChatUIKit.shared.theme.quinaryAccent }
    
    static var surface1: UIColor { SceytChatUIKit.shared.theme.surface1 }
    static var surface2: UIColor { SceytChatUIKit.shared.theme.surface2 }
    static var surface3: UIColor { SceytChatUIKit.shared.theme.surface3 }
    
    static var background: UIColor { SceytChatUIKit.shared.theme.background }
    static var backgroundMuted: UIColor { SceytChatUIKit.shared.theme.backgroundMuted }
    static var backgroundSections: UIColor { SceytChatUIKit.shared.theme.backgroundSections }
    static var backgroundDark: UIColor { SceytChatUIKit.shared.theme.backgroundDark }
    static var borders: UIColor { SceytChatUIKit.shared.theme.borders }
    static var iconInactive: UIColor { SceytChatUIKit.shared.theme.iconInactive }
    static var iconSecondary: UIColor { SceytChatUIKit.shared.theme.iconSecondary }
    static var overlayBackground1: UIColor { SceytChatUIKit.shared.theme.overlayBackground1 }
    static var overlayBackground2: UIColor { SceytChatUIKit.shared.theme.overlayBackground2 }
    
    static var primaryText: UIColor { SceytChatUIKit.shared.theme.primaryText }
    static var secondaryText: UIColor { SceytChatUIKit.shared.theme.secondaryText }
    static var footnoteText: UIColor { SceytChatUIKit.shared.theme.footnoteText }
    static var textOnPrimary: UIColor { SceytChatUIKit.shared.theme.textOnPrimary }
    
    static var bubbleOutgoing: UIColor { SceytChatUIKit.shared.theme.bubbleOutgoing }
    static var bubbleOutgoingX: UIColor { SceytChatUIKit.shared.theme.bubbleOutgoingX }
    static var bubbleIncoming: UIColor { SceytChatUIKit.shared.theme.bubbleIncoming }
    static var bubbleIncomingX: UIColor { SceytChatUIKit.shared.theme.bubbleIncomingX }
    
    static var stateError: UIColor { SceytChatUIKit.shared.theme.stateError }
    static var stateSuccess: UIColor { SceytChatUIKit.shared.theme.stateSuccess }
    static var stateAttention: UIColor { SceytChatUIKit.shared.theme.stateAttention }
    
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
