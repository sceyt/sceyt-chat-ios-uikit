//
//  SceytChatUIKit+Theme.swift
//
//
//  Created by Arthur Avagyan on 07.08.24.
//

import UIKit
import SceytChat

public extension SceytChatUIKit {
    public protocol ThemeProtocol {
        
        var accent: UIColor { get }
        var accent2: UIColor { get }
        var accent3: UIColor { get }
        var accent4: UIColor { get }
        var accent5: UIColor { get }
        
        var surface1: UIColor { get }
        var surface2: UIColor { get }
        var surface3: UIColor { get }
        
        var background: UIColor { get }
        var backgroundSecondary: UIColor { get }
        var backgroundSections: UIColor { get }
        var backgroundDark: UIColor { get }
        var border: UIColor { get }
        var iconInactive: UIColor { get }
        var iconSecondary: UIColor { get }
        var overlayBackground1: UIColor { get }
        var overlayBackground2: UIColor { get }
        
        var primaryText: UIColor { get }
        var secondaryText: UIColor { get }
        var footnoteText: UIColor { get }
        var onPrimary: UIColor { get }
        
        var stateWarning: UIColor { get }
        var stateSuccess: UIColor { get }
        var stateAttention: UIColor { get }
    }
}

public extension SceytChatUIKit {
    public class Theme: ThemeProtocol {
        
        public required init() { }
        
        public var accent: UIColor = Colors.accent
        public var accent2: UIColor = Colors.accent2
        public var accent3: UIColor = Colors.accent3
        public var accent4: UIColor = Colors.accent4
        public var accent5: UIColor = Colors.accent5
        
        public var surface1: UIColor = Colors.surface1
        public var surface2: UIColor = Colors.surface2
        public var surface3: UIColor = Colors.surface3
        
        public var background: UIColor = Colors.background
        public var backgroundSecondary: UIColor = Colors.backgroundSecondary
        public var backgroundSections: UIColor = Colors.backgroundSections
        public var backgroundDark: UIColor = Colors.backgroundDark
        public var border: UIColor = Colors.border
        public var iconInactive: UIColor = Colors.iconInactive
        public var iconSecondary: UIColor = Colors.iconSecondary
        public var overlayBackground1: UIColor = Colors.overlayBackground1
        public var overlayBackground2: UIColor = Colors.overlayBackground2
        
        public var primaryText: UIColor = Colors.primaryText
        public var secondaryText: UIColor = Colors.secondaryText
        public var footnoteText: UIColor = Colors.footnoteText
        public var onPrimary: UIColor = Colors.onPrimary
        
        public var stateWarning: UIColor = Colors.stateWarning
        public var stateSuccess: UIColor = Colors.stateSuccess
        public var stateAttention: UIColor = Colors.stateAttention
    }
}

public extension SceytChatUIKit.Theme {
    public static func with(
        _ populator: (inout SceytChatUIKit.Theme) throws -> ()
    ) rethrows -> SceytChatUIKit.Theme {
        var message = SceytChatUIKit.Theme()
        try populator(&message)
        return message
    }
}
