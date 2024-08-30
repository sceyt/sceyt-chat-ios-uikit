//
//  SceytChatUIKitTheme.swift
//
//
//  Created by Arthur Avagyan on 07.08.24.
//

import UIKit
import SceytChat

public protocol SceytChatUIKitThemeProtocol {
    static var primaryAccent: UIColor { get }
    static var secondaryAccent: UIColor { get }
    static var tertiaryAccent: UIColor { get }
    static var quaternaryAccent: UIColor { get }
    static var quinaryAccent: UIColor { get }
    
    static var surface1: UIColor { get }
    static var surface2: UIColor { get }
    static var surface3: UIColor { get }
    
    static var background: UIColor { get }
    static var backgroundMuted: UIColor { get }
    static var backgroundSections: UIColor { get }
    static var backgroundDark: UIColor { get }
    static var borders: UIColor { get }
    static var iconInactive: UIColor { get }
    static var iconSecondary: UIColor { get }
    static var overlayBackground1: UIColor { get }
    static var overlayBackground2: UIColor { get }
    
    static var primaryText: UIColor { get }
    static var secondaryText: UIColor { get }
    static var footnoteText: UIColor { get }
    static var textOnPrimary: UIColor { get }
    
    static var bubbleOutgoing: UIColor { get }
    static var bubbleOutgoingX: UIColor { get }
    static var bubbleIncoming: UIColor { get }
    static var bubbleIncomingX: UIColor { get }
    
    static var stateError: UIColor { get }
    static var stateSuccess: UIColor { get }
    static var stateAttention: UIColor { get }
}

public struct SceytChatUIKitTheme: SceytChatUIKitThemeProtocol {
    
    public static var primaryAccent: UIColor = UIColor(light: Light.primaryAccent, dark: Dark.primaryAccent)
    public static var secondaryAccent: UIColor = UIColor(light: Light.secondaryAccent, dark: Dark.secondaryAccent)
    public static var tertiaryAccent: UIColor = UIColor(light: Light.tertiaryAccent, dark: Dark.tertiaryAccent)
    public static var quaternaryAccent: UIColor = UIColor(light: Light.quaternaryAccent, dark: Dark.quaternaryAccent)
    public static var quinaryAccent: UIColor = UIColor(light: Light.quinaryAccent, dark: Dark.quinaryAccent)
    
    public static var surface1: UIColor = UIColor(light: Light.surface1, dark: Dark.surface1)
    public static var surface2: UIColor = UIColor(light: Light.surface2, dark: Dark.surface2)
    public static var surface3: UIColor = UIColor(light: Light.surface3, dark: Dark.surface3)
    
    public static var background: UIColor = UIColor(light: Light.background, dark: Dark.background)
    public static var backgroundMuted: UIColor = UIColor(light: Light.backgroundMuted, dark: Dark.backgroundMuted)
    public static var backgroundSections: UIColor = UIColor(light: Light.backgroundSections, dark: Dark.backgroundSections)
    public static var backgroundDark: UIColor = UIColor(light: Light.backgroundDark, dark: Dark.backgroundDark)
    public static var borders: UIColor = UIColor(light: Light.borders, dark: Dark.borders)
    public static var iconInactive: UIColor = UIColor(light: Light.iconInactive, dark: Dark.iconInactive)
    public static var iconSecondary: UIColor = UIColor(light: Light.iconSecondary, dark: Dark.iconSecondary)
    public static var overlayBackground1: UIColor = UIColor(light: Light.overlayBackground1, dark: Dark.overlayBackground1)
    public static var overlayBackground2: UIColor = UIColor(light: Light.overlayBackground2, dark: Dark.overlayBackground2)
    
    public static var primaryText: UIColor = UIColor(light: Light.primaryText, dark: Dark.primaryText)
    public static var secondaryText: UIColor = UIColor(light: Light.secondaryText, dark: Dark.secondaryText)
    public static var footnoteText: UIColor = UIColor(light: Light.footnoteText, dark: Dark.footnoteText)
    public static var textOnPrimary: UIColor = UIColor(light: Light.textOnPrimary, dark: Dark.textOnPrimary)
    
    public static var bubbleOutgoing: UIColor = primaryAccent.generateSecondaryColor() // UIColor(light: Light.bubbleOutgoing, dark: Dark.bubbleOutgoing)
    public static var bubbleOutgoingX: UIColor = primaryAccent.generateTertiaryColor() // UIColor(light: Light.bubbleOutgoingX, dark: Dark.bubbleOutgoingX)
    public static var bubbleIncoming: UIColor = UIColor(light: Light.bubbleIncoming, dark: Dark.bubbleIncoming)
    public static var bubbleIncomingX: UIColor = UIColor(light: Light.bubbleIncomingX, dark: Dark.bubbleIncomingX)
    
    public static var stateError: UIColor = UIColor(light: Light.stateError, dark: Dark.stateError)
    public static var stateSuccess: UIColor = UIColor(light: Light.stateSuccess, dark: Dark.stateSuccess)
    public static var stateAttention: UIColor = UIColor(light: Light.stateAttention, dark: Dark.stateAttention)
}

public extension SceytChatUIKitTheme {
    
    public struct Light {
        public static var primaryAccent: UIColor = UIColor(rgb: 0x5159F6)
        public static var secondaryAccent: UIColor = UIColor(rgb: 0xFBB019)
        public static var tertiaryAccent: UIColor = UIColor(rgb: 0xB463E7)
        public static var quaternaryAccent: UIColor = UIColor(rgb: 0x63AFFF)
        public static var quinaryAccent: UIColor = UIColor(rgb: 0x67D292)
        
        public static var surface1: UIColor = UIColor(rgb: 0xF1F2F6)
        public static var surface2: UIColor = UIColor(rgb: 0xE4E6EE)
        public static var surface3: UIColor = UIColor(rgb: 0xA0A1B0)
        
        public static var background: UIColor = UIColor(rgb: 0xFFFFFF)
        public static var backgroundMuted: UIColor = UIColor(rgb: 0xF1F2F6)
        public static var backgroundSections: UIColor = UIColor(rgb: 0xFFFFFF)
        public static var backgroundDark: UIColor = UIColor(rgb: 0x19191B)
        public static var borders: UIColor = UIColor(rgb: 0xE4E6EE)
        public static var iconInactive: UIColor = UIColor(rgb: 0xA0A1B0)
        public static var iconSecondary: UIColor = UIColor(rgb: 0x707388)
        public static var overlayBackground1: UIColor = UIColor(rgb: 0x000000, alpha: 0.4)
        public static var overlayBackground2: UIColor = UIColor(rgb: 0x111539, alpha: 0.4)
        
        public static var primaryText: UIColor = UIColor(rgb: 0x111539)
        public static var secondaryText: UIColor = UIColor(rgb: 0x707388)
        public static var footnoteText: UIColor = UIColor(rgb: 0xA0A1B0)
        public static var textOnPrimary: UIColor = UIColor(rgb: 0xFFFFFF)
        
//        public static var bubbleOutgoing: UIColor = UIColor(rgb: 0xE3E7FF)
//        public static var bubbleOutgoingX: UIColor = UIColor(rgb: 0xD1D8FF)
        public static var bubbleIncoming: UIColor = UIColor(rgb: 0xF1F2F6)
        public static var bubbleIncomingX: UIColor = UIColor(rgb: 0xE4E6EE)
        
        public static var stateError: UIColor = UIColor(rgb: 0xFA4C56)
        public static var stateSuccess: UIColor = UIColor(rgb: 0x24C383)
        public static var stateAttention: UIColor = UIColor(rgb: 0xFBB019)
    }
}

public extension SceytChatUIKitTheme {
    
    public struct Dark {
        public static var primaryAccent: UIColor = UIColor(rgb: 0x6B72FF)
        public static var secondaryAccent: UIColor = UIColor(rgb: 0xFBB019)
        public static var tertiaryAccent: UIColor = UIColor(rgb: 0xB463E7)
        public static var quaternaryAccent: UIColor = UIColor(rgb: 0x63AFFF)
        public static var quinaryAccent: UIColor = UIColor(rgb: 0x67D292)
        
        public static var surface1: UIColor = UIColor(rgb: 0x232324)
        public static var surface2: UIColor = UIColor(rgb: 0x303032)
        public static var surface3: UIColor = UIColor(rgb: 0x3B3B3D)
        
        public static var background: UIColor = UIColor(rgb: 0x19191B)
        public static var backgroundMuted: UIColor = UIColor(rgb: 0x19191B)
        public static var backgroundSections: UIColor = UIColor(rgb: 0x232324)
        public static var backgroundDark: UIColor = UIColor(rgb: 0x19191B)
        public static var borders: UIColor = UIColor(rgb: 0x303032)
        public static var iconInactive: UIColor = UIColor(rgb: 0x76787A)
        public static var iconSecondary: UIColor = UIColor(rgb: 0x969A9F)
        public static var overlayBackground1: UIColor = UIColor(rgb: 0x000000, alpha: 0.4)
        public static var overlayBackground2: UIColor = UIColor(rgb: 0x111539, alpha: 0.4)
        
        public static var primaryText: UIColor = UIColor(rgb: 0xE1E3E6)
        public static var secondaryText: UIColor = UIColor(rgb: 0x969A9F)
        public static var footnoteText: UIColor = UIColor(rgb: 0x76787A)
        public static var textOnPrimary: UIColor = UIColor(rgb: 0xFFFFFF)
        
//        public static var bubbleOutgoing: UIColor = UIColor(rgb: 0x212239)
//        public static var bubbleOutgoingX: UIColor = UIColor(rgb: 0x2E3052)
        public static var bubbleIncoming: UIColor = UIColor(rgb: 0x232324)
        public static var bubbleIncomingX: UIColor = UIColor(rgb: 0x303032)
        
        public static var stateError: UIColor = UIColor(rgb: 0xFA4C56)
        public static var stateSuccess: UIColor = UIColor(rgb: 0x24C383)
        public static var stateAttention: UIColor = UIColor(rgb: 0xFBB019)
    }
}

fileprivate extension UIColor {
    // Helper function to apply an offset to a color component
    private func offsetColorComponent(_ component: Int, by offset: Int) -> Int {
        return min(max(component + offset, 0), 255)
    }
    
    // Function to generate secondary color
    func generateSecondaryColor() -> UIColor {
        return self.adjustColor(lightOffset: (red: 120, green: 117, blue: 255),
                                darkOffset: (red: -74, green: -80, blue: -198))
    }
    
    // Function to generate tertiary color
    func generateTertiaryColor() -> UIColor {
        return self.adjustColor(lightOffset: (red: 102, green: 102, blue: 244),
                                darkOffset: (red: -61, green: -66, blue: -173))
    }
        
    // General function to adjust color based on light and dark mode offsets
    private func adjustColor(lightOffset: (red: Int, green: Int, blue: Int),
                             darkOffset: (red: Int, green: Int, blue: Int)) -> UIColor {
        var lightRed: CGFloat = 0, lightGreen: CGFloat = 0, lightBlue: CGFloat = 0, lightAlpha: CGFloat = 0
        var darkRed: CGFloat = 0, darkGreen: CGFloat = 0, darkBlue: CGFloat = 0, darkAlpha: CGFloat = 0
        
        self.getRed(&lightRed, green: &lightGreen, blue: &lightBlue, alpha: &lightAlpha)
        self.getRed(&darkRed, green: &darkGreen, blue: &darkBlue, alpha: &darkAlpha)
        
        lightRed = lightRed * 255
        lightGreen = lightGreen * 255
        lightBlue = lightBlue * 255
        lightAlpha = lightAlpha * 255

        
        darkRed = darkRed * 255
        darkGreen = darkGreen * 255
        darkBlue = darkBlue * 255
        darkAlpha = darkAlpha * 255

        
        let lightColor = UIColor(
            red: offsetColorComponent(Int(lightRed), by: lightOffset.red),
            green: offsetColorComponent(Int(lightGreen), by: lightOffset.green),
            blue: offsetColorComponent(Int(lightBlue), by: lightOffset.blue),
            alpha: Int(lightAlpha)
        )
        
        let darkColor = UIColor(
            red: offsetColorComponent(Int(darkRed), by: darkOffset.red),
            green: offsetColorComponent(Int(darkGreen), by: darkOffset.green),
            blue: offsetColorComponent(Int(darkBlue), by: darkOffset.blue),
            alpha: Int(darkAlpha)
        )
        
        return UIColor(light: lightColor, dark: darkColor)
    }

    convenience init(red: Int, green: Int, blue: Int, alpha: Int = 255) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        assert(alpha >= 0 && alpha <= 255, "Invalid alpha component")
        
        self.init(red: CGFloat(red) / 255.0,
                  green: CGFloat(green) / 255.0,
                  blue: CGFloat(blue) / 255.0,
                  alpha: CGFloat(alpha) / 255.0)
    }
}
