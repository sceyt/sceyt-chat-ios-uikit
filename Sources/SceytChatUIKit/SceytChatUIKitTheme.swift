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
    
    public var primaryAccent: UIColor = UIColor(light: Colors.Light.primaryAccent, dark: Colors.Dark.primaryAccent)
    public var secondaryAccent: UIColor = UIColor(light: Colors.Light.secondaryAccent, dark: Colors.Dark.secondaryAccent)
    public var tertiaryAccent: UIColor = UIColor(light: Colors.Light.tertiaryAccent, dark: Colors.Dark.tertiaryAccent)
    public var quaternaryAccent: UIColor = UIColor(light: Colors.Light.quaternaryAccent, dark: Colors.Dark.quaternaryAccent)
    public var quinaryAccent: UIColor = UIColor(light: Colors.Light.quinaryAccent, dark: Colors.Dark.quinaryAccent)
    
    public var surface1: UIColor = UIColor(light: Colors.Light.surface1, dark: Colors.Dark.surface1)
    public var surface2: UIColor = UIColor(light: Colors.Light.surface2, dark: Colors.Dark.surface2)
    public var surface3: UIColor = UIColor(light: Colors.Light.surface3, dark: Colors.Dark.surface3)
    
    public var background: UIColor = UIColor(light: Colors.Light.background, dark: Colors.Dark.background)
    public var backgroundMuted: UIColor = UIColor(light: Colors.Light.backgroundMuted, dark: Colors.Dark.backgroundMuted)
    public var backgroundSections: UIColor = UIColor(light: Colors.Light.backgroundSections, dark: Colors.Dark.backgroundSections)
    public var backgroundDark: UIColor = UIColor(light: Colors.Light.backgroundDark, dark: Colors.Dark.backgroundDark)
    public var borders: UIColor = UIColor(light: Colors.Light.borders, dark: Colors.Dark.borders)
    public var iconInactive: UIColor = UIColor(light: Colors.Light.iconInactive, dark: Colors.Dark.iconInactive)
    public var iconSecondary: UIColor = UIColor(light: Colors.Light.iconSecondary, dark: Colors.Dark.iconSecondary)
    public var overlayBackground1: UIColor = UIColor(light: Colors.Light.overlayBackground1, dark: Colors.Dark.overlayBackground1)
    public var overlayBackground2: UIColor = UIColor(light: Colors.Light.overlayBackground2, dark: Colors.Dark.overlayBackground2)
    
    public var primaryText: UIColor = UIColor(light: Colors.Light.primaryText, dark: Colors.Dark.primaryText)
    public var secondaryText: UIColor = UIColor(light: Colors.Light.secondaryText, dark: Colors.Dark.secondaryText)
    public var footnoteText: UIColor = UIColor(light: Colors.Light.footnoteText, dark: Colors.Dark.footnoteText)
    public var textOnPrimary: UIColor = UIColor(light: Colors.Light.textOnPrimary, dark: Colors.Dark.textOnPrimary)
    
    public var stateError: UIColor = UIColor(light: Colors.Light.stateError, dark: Colors.Dark.stateError)
    public var stateSuccess: UIColor = UIColor(light: Colors.Light.stateSuccess, dark: Colors.Dark.stateSuccess)
    public var stateAttention: UIColor = UIColor(light: Colors.Light.stateAttention, dark: Colors.Dark.stateAttention)
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
