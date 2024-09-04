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

public struct Colors {
    // These colors are included into the default theme
    public static let primaryAccent: UIColor = UIColor(light: UIColor(rgb: 0x5159F6), dark: UIColor(rgb: 0x6B72FF))
    public static let secondaryAccent: UIColor = UIColor(light: UIColor(rgb: 0xFBB019), dark: UIColor(rgb: 0xFBB019))
    public static let tertiaryAccent: UIColor = UIColor(light: UIColor(rgb: 0xB463E7), dark: UIColor(rgb: 0xB463E7))
    public static let quaternaryAccent: UIColor = UIColor(light: UIColor(rgb: 0x63AFFF), dark: UIColor(rgb: 0x63AFFF))
    public static let quinaryAccent: UIColor = UIColor(light: UIColor(rgb: 0x67D292), dark: UIColor(rgb: 0x67D292))
    
    public static let surface1: UIColor = UIColor(light: UIColor(rgb: 0xF1F2F6), dark: UIColor(rgb: 0x232324))
    public static let surface2: UIColor = UIColor(light: UIColor(rgb: 0xE4E6EE), dark: UIColor(rgb: 0x303032))
    public static let surface3: UIColor = UIColor(light: UIColor(rgb: 0xA0A1B0), dark: UIColor(rgb: 0x3B3B3D))
    
    public static let background: UIColor = UIColor(light: UIColor(rgb: 0xFFFFFF), dark: UIColor(rgb: 0x19191B))
    public static let backgroundMuted: UIColor = UIColor(light: UIColor(rgb: 0xF1F2F6), dark: UIColor(rgb: 0x19191B))
    public static let backgroundSections: UIColor = UIColor(light: UIColor(rgb: 0xFFFFFF), dark: UIColor(rgb: 0x232324))
    public static let backgroundDark: UIColor = UIColor(light: UIColor(rgb: 0x19191B), dark: UIColor(rgb: 0x19191B))
    public static let borders: UIColor = UIColor(light: UIColor(rgb: 0xE4E6EE), dark: UIColor(rgb: 0x303032))
    public static let iconInactive: UIColor = UIColor(light: UIColor(rgb: 0xA0A1B0), dark: UIColor(rgb: 0x76787A))
    public static let iconSecondary: UIColor = UIColor(light: UIColor(rgb: 0x707388), dark: UIColor(rgb: 0x969A9F))
    public static let overlayBackground1: UIColor = UIColor(light: UIColor(rgb: 0x000000, alpha: 0.4), dark: UIColor(rgb: 0x000000, alpha: 0.4))
    public static let overlayBackground2: UIColor = UIColor(light: UIColor(rgb: 0x111539, alpha: 0.4), dark: UIColor(rgb: 0x111539, alpha: 0.4))
    
    public static let primaryText: UIColor = UIColor(light: UIColor(rgb: 0x111539), dark: UIColor(rgb: 0xE1E3E6))
    public static let secondaryText: UIColor = UIColor(light: UIColor(rgb: 0x707388), dark: UIColor(rgb: 0x969A9F))
    public static let footnoteText: UIColor = UIColor(light: UIColor(rgb: 0xA0A1B0), dark: UIColor(rgb: 0x76787A))
    public static let textOnPrimary: UIColor = UIColor(light: UIColor(rgb: 0xFFFFFF), dark: UIColor(rgb: 0xFFFFFF))
    
    public static let stateError: UIColor = UIColor(light: UIColor(rgb: 0xFA4C56), dark: UIColor(rgb: 0xFA4C56))
    public static let stateSuccess: UIColor = UIColor(light: UIColor(rgb: 0x24C383), dark: UIColor(rgb: 0x24C383))
    public static let stateAttention: UIColor = UIColor(light: UIColor(rgb: 0xFBB019), dark: UIColor(rgb: 0xFBB019))
    
    // These colors are not a part of the theme, but they use theme's values by default
    public static var bubbleIncoming: UIColor = UIColor(light: UIColor(rgb: 0xF1F2F6), dark: UIColor(rgb: 0x232324))
    public static var bubbleIncomingX: UIColor = UIColor(light: UIColor(rgb: 0xE4E6EE), dark: UIColor(rgb: 0x303032))
    public static var bubbleOutgoing: UIColor = UIColor(light: .primaryAccent.light.withAlphaComponent(0.14).blendColors(with: .background.light),
                                                        dark: .primaryAccent.dark.withAlphaComponent(0.14).blendColors(with: .background.dark))
    public static var bubbleOutgoingX: UIColor = UIColor(light: .primaryAccent.light.withAlphaComponent(0.24).blendColors(with: .background.light),
                                                         dark: .primaryAccent.dark.withAlphaComponent(0.24).blendColors(with: .background.dark))
}

public extension UIColor {
    
    func blendColors(with background: UIColor) -> UIColor {
        var fgRed: CGFloat = 0, fgGreen: CGFloat = 0, fgBlue: CGFloat = 0, fgAlpha: CGFloat = 0
        var bgRed: CGFloat = 0, bgGreen: CGFloat = 0, bgBlue: CGFloat = 0, bgAlpha: CGFloat = 0
        
        self.getRed(&fgRed, green: &fgGreen, blue: &fgBlue, alpha: &fgAlpha)
        background.getRed(&bgRed, green: &bgGreen, blue: &bgBlue, alpha: &bgAlpha)
        
        let blendedAlpha = fgAlpha + bgAlpha * (1.0 - fgAlpha)
        let blendedRed = (fgRed * fgAlpha + bgRed * bgAlpha * (1.0 - fgAlpha)) / blendedAlpha
        let blendedGreen = (fgGreen * fgAlpha + bgGreen * bgAlpha * (1.0 - fgAlpha)) / blendedAlpha
        let blendedBlue = (fgBlue * fgAlpha + bgBlue * bgAlpha * (1.0 - fgAlpha)) / blendedAlpha
        
        return UIColor(red: blendedRed, green: blendedGreen, blue: blendedBlue, alpha: blendedAlpha)
    }
    
    public var light: UIColor {
        resolvedColor(with: .init(userInterfaceStyle: .light))
    }
    
    public var dark: UIColor {
        resolvedColor(with: .init(userInterfaceStyle: .dark))
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
