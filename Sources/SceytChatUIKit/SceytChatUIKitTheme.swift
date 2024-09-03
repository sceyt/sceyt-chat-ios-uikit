//
//  SceytChatUIKitTheme.swift
//
//
//  Created by Arthur Avagyan on 07.08.24.
//

import UIKit
import SceytChat

public protocol SceytChatUIKitThemeProtocol {
    
    var primaryAccent: UIColor { get }
    var secondaryAccent: UIColor { get }
    var tertiaryAccent: UIColor { get }
    var quaternaryAccent: UIColor { get }
    var quinaryAccent: UIColor { get }
    
    var surface1: UIColor { get }
    var surface2: UIColor { get }
    var surface3: UIColor { get }
    
    var background: UIColor { get }
    var backgroundMuted: UIColor { get }
    var backgroundSections: UIColor { get }
    var backgroundDark: UIColor { get }
    var borders: UIColor { get }
    var iconInactive: UIColor { get }
    var iconSecondary: UIColor { get }
    var overlayBackground1: UIColor { get }
    var overlayBackground2: UIColor { get }
    
    var primaryText: UIColor { get }
    var secondaryText: UIColor { get }
    var footnoteText: UIColor { get }
    var textOnPrimary: UIColor { get }
        
    var stateError: UIColor { get }
    var stateSuccess: UIColor { get }
    var stateAttention: UIColor { get }
}

public class SceytChatUIKitTheme: SceytChatUIKitThemeProtocol {
    
    public required init() { }
    
    public var primaryAccent: UIColor = UIColor(light: Light.primaryAccent, dark: Dark.primaryAccent)
    public var secondaryAccent: UIColor = UIColor(light: Light.secondaryAccent, dark: Dark.secondaryAccent)
    public var tertiaryAccent: UIColor = UIColor(light: Light.tertiaryAccent, dark: Dark.tertiaryAccent)
    public var quaternaryAccent: UIColor = UIColor(light: Light.quaternaryAccent, dark: Dark.quaternaryAccent)
    public var quinaryAccent: UIColor = UIColor(light: Light.quinaryAccent, dark: Dark.quinaryAccent)
    
    public var surface1: UIColor = UIColor(light: Light.surface1, dark: Dark.surface1)
    public var surface2: UIColor = UIColor(light: Light.surface2, dark: Dark.surface2)
    public var surface3: UIColor = UIColor(light: Light.surface3, dark: Dark.surface3)
    
    public var background: UIColor = UIColor(light: Light.background, dark: Dark.background)
    public var backgroundMuted: UIColor = UIColor(light: Light.backgroundMuted, dark: Dark.backgroundMuted)
    public var backgroundSections: UIColor = UIColor(light: Light.backgroundSections, dark: Dark.backgroundSections)
    public var backgroundDark: UIColor = UIColor(light: Light.backgroundDark, dark: Dark.backgroundDark)
    public var borders: UIColor = UIColor(light: Light.borders, dark: Dark.borders)
    public var iconInactive: UIColor = UIColor(light: Light.iconInactive, dark: Dark.iconInactive)
    public var iconSecondary: UIColor = UIColor(light: Light.iconSecondary, dark: Dark.iconSecondary)
    public var overlayBackground1: UIColor = UIColor(light: Light.overlayBackground1, dark: Dark.overlayBackground1)
    public var overlayBackground2: UIColor = UIColor(light: Light.overlayBackground2, dark: Dark.overlayBackground2)
    
    public var primaryText: UIColor = UIColor(light: Light.primaryText, dark: Dark.primaryText)
    public var secondaryText: UIColor = UIColor(light: Light.secondaryText, dark: Dark.secondaryText)
    public var footnoteText: UIColor = UIColor(light: Light.footnoteText, dark: Dark.footnoteText)
    public var textOnPrimary: UIColor = UIColor(light: Light.textOnPrimary, dark: Dark.textOnPrimary)
    
    public var stateError: UIColor = UIColor(light: Light.stateError, dark: Dark.stateError)
    public var stateSuccess: UIColor = UIColor(light: Light.stateSuccess, dark: Dark.stateSuccess)
    public var stateAttention: UIColor = UIColor(light: Light.stateAttention, dark: Dark.stateAttention)
}

public extension SceytChatUIKitTheme {
    public static func with(
        _ populator: (inout SceytChatUIKitTheme) throws -> ()
    ) rethrows -> SceytChatUIKitTheme {
        var message = SceytChatUIKitTheme()
        try populator(&message)
        return message
    }
}

public extension SceytChatUIKitTheme {
    
    public struct Light {
        public static let primaryAccent: UIColor = UIColor(rgb: 0x5159F6)
        public static let secondaryAccent: UIColor = UIColor(rgb: 0xFBB019)
        public static let tertiaryAccent: UIColor = UIColor(rgb: 0xB463E7)
        public static let quaternaryAccent: UIColor = UIColor(rgb: 0x63AFFF)
        public static let quinaryAccent: UIColor = UIColor(rgb: 0x67D292)
        
        public static let surface1: UIColor = UIColor(rgb: 0xF1F2F6)
        public static let surface2: UIColor = UIColor(rgb: 0xE4E6EE)
        public static let surface3: UIColor = UIColor(rgb: 0xA0A1B0)
        
        public static let background: UIColor = UIColor(rgb: 0xFFFFFF)
        public static let backgroundMuted: UIColor = UIColor(rgb: 0xF1F2F6)
        public static let backgroundSections: UIColor = UIColor(rgb: 0xFFFFFF)
        public static let backgroundDark: UIColor = UIColor(rgb: 0x19191B)
        public static let borders: UIColor = UIColor(rgb: 0xE4E6EE)
        public static let iconInactive: UIColor = UIColor(rgb: 0xA0A1B0)
        public static let iconSecondary: UIColor = UIColor(rgb: 0x707388)
        public static let overlayBackground1: UIColor = UIColor(rgb: 0x000000, alpha: 0.4)
        public static let overlayBackground2: UIColor = UIColor(rgb: 0x111539, alpha: 0.4)
        
        public static let primaryText: UIColor = UIColor(rgb: 0x111539)
        public static let secondaryText: UIColor = UIColor(rgb: 0x707388)
        public static let footnoteText: UIColor = UIColor(rgb: 0xA0A1B0)
        public static let textOnPrimary: UIColor = UIColor(rgb: 0xFFFFFF)
        
        public static let bubbleIncoming: UIColor = UIColor(rgb: 0xF1F2F6)
        public static let bubbleIncomingX: UIColor = UIColor(rgb: 0xE4E6EE)
        
        public static let stateError: UIColor = UIColor(rgb: 0xFA4C56)
        public static let stateSuccess: UIColor = UIColor(rgb: 0x24C383)
        public static let stateAttention: UIColor = UIColor(rgb: 0xFBB019)
    }
}

public extension SceytChatUIKitTheme {
    
    public struct Dark {
        public static let primaryAccent: UIColor = UIColor(rgb: 0x6B72FF)
        public static let secondaryAccent: UIColor = UIColor(rgb: 0xFBB019)
        public static let tertiaryAccent: UIColor = UIColor(rgb: 0xB463E7)
        public static let quaternaryAccent: UIColor = UIColor(rgb: 0x63AFFF)
        public static let quinaryAccent: UIColor = UIColor(rgb: 0x67D292)
        
        public static let surface1: UIColor = UIColor(rgb: 0x232324)
        public static let surface2: UIColor = UIColor(rgb: 0x303032)
        public static let surface3: UIColor = UIColor(rgb: 0x3B3B3D)
        
        public static let background: UIColor = UIColor(rgb: 0x19191B)
        public static let backgroundMuted: UIColor = UIColor(rgb: 0x19191B)
        public static let backgroundSections: UIColor = UIColor(rgb: 0x232324)
        public static let backgroundDark: UIColor = UIColor(rgb: 0x19191B)
        public static let borders: UIColor = UIColor(rgb: 0x303032)
        public static let iconInactive: UIColor = UIColor(rgb: 0x76787A)
        public static let iconSecondary: UIColor = UIColor(rgb: 0x969A9F)
        public static let overlayBackground1: UIColor = UIColor(rgb: 0x000000, alpha: 0.4)
        public static let overlayBackground2: UIColor = UIColor(rgb: 0x111539, alpha: 0.4)
        
        public static let primaryText: UIColor = UIColor(rgb: 0xE1E3E6)
        public static let secondaryText: UIColor = UIColor(rgb: 0x969A9F)
        public static let footnoteText: UIColor = UIColor(rgb: 0x76787A)
        public static let textOnPrimary: UIColor = UIColor(rgb: 0xFFFFFF)
        
        public static let bubbleIncoming: UIColor = UIColor(rgb: 0x232324)
        public static let bubbleIncomingX: UIColor = UIColor(rgb: 0x303032)
        
        public static let stateError: UIColor = UIColor(rgb: 0xFA4C56)
        public static let stateSuccess: UIColor = UIColor(rgb: 0x24C383)
        public static let stateAttention: UIColor = UIColor(rgb: 0xFBB019)
    }
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
    
    public var lightColor: UIColor {
        resolvedColor(with: .init(userInterfaceStyle: .light))
    }
    
    public var darkColor: UIColor {
        resolvedColor(with: .init(userInterfaceStyle: .dark))
    }
}
