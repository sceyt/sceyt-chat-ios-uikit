//
//  Appearance+Colors.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

typealias Colors = Appearance.Colors

public extension Appearance {
    
    struct Colors {
        
//        public static var kitBlue: UIColor = SceytChatUIKitTheme.primaryAccent //UIColor(light: 0x5159F6, dark: 0x6B72FF)
//        public static var kitRed: UIColor = SceytChatUIKitTheme.stateError //UIColor(light: 0xF23F51, dark: 0xF23F51)
//        public static var textBlack: UIColor = SceytChatUIKitTheme.primaryText //UIColor(light: 0x111539, dark: 0xE1E3E6)
//        public static var textGray: UIColor = SceytChatUIKitTheme.secondaryText// UIColor(light: 0x707388, dark: 0x969A9F)
        public static var textGray2: UIColor = UIColor(light: 0x9B9DA8, dark: 0x76787A)
        public static var textGray3: UIColor = UIColor(light: 0xA0A1B0, dark: 0x969A9F)
        public static var textWhite: UIColor = UIColor(light: 0xffffff, dark: 0x969A9F)
        public static var textRed: UIColor = UIColor(light: 0xED4D60, dark: 0xED4D60)
//        public static var background: UIColor = SceytChatUIKitTheme.background //UIColor(light: 0xFFFFFF, dark: 0x19191b)
        public static var background2: UIColor = UIColor(light: 0xF1F2F6, dark: 0x232324)
        public static var background3: UIColor = UIColor(light: 0xFFFFFF, dark: 0x232324)
        public static var background4: UIColor = UIColor(light: 0xF1F2F6, dark: 0x19191B)
//        public static var backgroundTransparent: UIColor = SceytChatUIKitTheme.overlayBackground40//UIColor(light: .init(rgb: 0x111539, alpha: 0.4),
//                                                                   dark: .init(rgb: 0x000000, alpha: 0.5))
        
//        public static var success: UIColor = SceytChatUIKitTheme.stateSuccess //UIColor(light: 0x31C48D, dark: 0x31C48D)
// //        public static var info: UIColor = UIColor(light: 0x4BBEFD, dark: 0x4BBEFD)
//        public static var warning: UIColor = SceytChatUIKitTheme.stateAttention //UIColor(light: 0xF88E69, dark: 0xF88E69)
//        public static var error: UIColor = SceytChatUIKitTheme.stateError //  UIColor(light: 0xF23F51, dark: 0xF23F51)
        public static var initialColors: [UIColor] = [ UIColor(rgb: 0x4F6AFF),
                                                       UIColor(rgb: 0xFBB019),
                                                       UIColor(rgb: 0x00CC99),
                                                       UIColor(rgb: 0x63AFFF),
                                                       UIColor(rgb: 0xFF3E74),
                                                       UIColor(rgb: 0x9F35E7) ]
        
        public static var separator: UIColor = .init(light: 0xE8E9EE, dark: 0x303032)
        public static var highlighted: UIColor = .init(light: 0xF1F2F6, dark: 0x303032)
        
        public init() {}
        
        public static func initial(title: String) -> UIColor {
            initialColors[abs(title.hash) % initialColors.count]
        }
        
    }
}

public extension UIColor {
    private typealias Colors = Appearance.Colors
    
    static var primaryAccent: UIColor { SceytChatUIKitTheme.primaryAccent }
    static var stateError: UIColor { SceytChatUIKitTheme.stateError }
    static var primaryText: UIColor { SceytChatUIKitTheme.primaryText }
    static var secondaryText: UIColor { SceytChatUIKitTheme.secondaryText }
    static var textGray2: UIColor { Colors.textGray2 }
    static var textGray3: UIColor { Colors.textGray3 }
    static var textWhite: UIColor { Colors.textWhite }
    static var textRed: UIColor { Colors.textRed }
    static var background: UIColor { SceytChatUIKitTheme.background }
    static var background2: UIColor { Colors.background2 }
    static var background3: UIColor { Colors.background3 }
    static var background4: UIColor { Colors.background4 }
    static var overlayBackground40: UIColor { SceytChatUIKitTheme.overlayBackground40 }
    static var stateSuccess: UIColor { SceytChatUIKitTheme.stateSuccess }
    static var stateAttention: UIColor { SceytChatUIKitTheme.stateAttention }
    static var separator: UIColor { Colors.separator }

    static var initialColors: [UIColor] { Colors.initialColors }
    
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
