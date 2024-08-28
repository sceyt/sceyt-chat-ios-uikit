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
    static var borders: UIColor { get }
    static var iconInactive: UIColor { get }
    static var iconSecondary: UIColor { get }
    static var overlayBackground50: UIColor { get }
    static var overlayBackground40: UIColor { get }
    static var overlayBackgroundMixed: UIColor { get }
    
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
    public static var borders: UIColor = UIColor(light: Light.borders, dark: Dark.borders)
    public static var iconInactive: UIColor = UIColor(light: Light.iconInactive, dark: Dark.iconInactive)
    public static var iconSecondary: UIColor = UIColor(light: Light.iconSecondary, dark: Dark.iconSecondary)
    public static var overlayBackground50: UIColor = UIColor(light: Light.overlayBackground50, dark: Dark.overlayBackground50)
    public static var overlayBackground40: UIColor = UIColor(light: Light.overlayBackground40, dark: Dark.overlayBackground40)
    public static var overlayBackgroundMixed: UIColor = UIColor(light: Light.overlayBackground40, dark: Dark.overlayBackground50)
    
    public static var primaryText: UIColor = UIColor(light: Light.primaryText, dark: Dark.primaryText)
    public static var secondaryText: UIColor = UIColor(light: Light.secondaryText, dark: Dark.secondaryText)
    public static var footnoteText: UIColor = UIColor(light: Light.footnoteText, dark: Dark.footnoteText)
    public static var textOnPrimary: UIColor = UIColor(light: Light.textOnPrimary, dark: Dark.textOnPrimary)
    
    public static var bubbleOutgoing: UIColor = UIColor(light: Light.bubbleOutgoing, dark: Dark.bubbleOutgoing)
    public static var bubbleOutgoingX: UIColor = UIColor(light: Light.bubbleOutgoingX, dark: Dark.bubbleOutgoingX)
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
        public static var borders: UIColor = UIColor(rgb: 0xE4E6EE)
        public static var iconInactive: UIColor = UIColor(rgb: 0xA0A1B0)
        public static var iconSecondary: UIColor = UIColor(rgb: 0x707388)
        public static var overlayBackground50: UIColor = UIColor(rgb: 0x000000, alpha: 0.5)
        public static var overlayBackground40: UIColor = UIColor(rgb: 0x111539, alpha: 0.4)
        
        public static var primaryText: UIColor = UIColor(rgb: 0x111539)
        public static var secondaryText: UIColor = UIColor(rgb: 0x707388)
        public static var footnoteText: UIColor = UIColor(rgb: 0xA0A1B0)
        public static var textOnPrimary: UIColor = UIColor(rgb: 0xFFFFFF)
        
        public static var bubbleOutgoing: UIColor = UIColor(rgb: 0xE3E7FF)
        public static var bubbleOutgoingX: UIColor = UIColor(rgb: 0xD1D8FF)
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
        public static var borders: UIColor = UIColor(rgb: 0x303032)
        public static var iconInactive: UIColor = UIColor(rgb: 0x76787A)
        public static var iconSecondary: UIColor = UIColor(rgb: 0x969A9F)
        public static var overlayBackground50: UIColor = UIColor(rgb: 0x000000, alpha: 0.5)
        public static var overlayBackground40: UIColor = UIColor(rgb: 0x111539, alpha: 0.4)
        
        public static var primaryText: UIColor = UIColor(rgb: 0xE1E3E6)
        public static var secondaryText: UIColor = UIColor(rgb: 0x969A9F)
        public static var footnoteText: UIColor = UIColor(rgb: 0x76787A)
        public static var textOnPrimary: UIColor = UIColor(rgb: 0xFFFFFF)
        
        public static var bubbleOutgoing: UIColor = UIColor(rgb: 0x212239)
        public static var bubbleOutgoingX: UIColor = UIColor(rgb: 0x2E3052)
        public static var bubbleIncoming: UIColor = UIColor(rgb: 0x232324)
        public static var bubbleIncomingX: UIColor = UIColor(rgb: 0x303032)
        
        public static var stateError: UIColor = UIColor(rgb: 0xFA4C56)
        public static var stateSuccess: UIColor = UIColor(rgb: 0x24C383)
        public static var stateAttention: UIColor = UIColor(rgb: 0xFBB019)
    }
}
