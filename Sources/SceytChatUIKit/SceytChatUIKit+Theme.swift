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
        
        var primaryAccent: UIColor { get }
        var secondaryAccent: UIColor { get }
        var tertiaryAccent: UIColor { get }
        var quaternaryAccent: UIColor { get }
        var quinaryAccent: UIColor { get }
        
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
        var textOnPrimary: UIColor { get }
        
        var stateError: UIColor { get }
        var stateSuccess: UIColor { get }
        var stateAttention: UIColor { get }
    }
}

public extension SceytChatUIKit {
    public class Theme: ThemeProtocol {
        
        public required init() { }
        
        public var primaryAccent: UIColor = Colors.primaryAccent
        public var secondaryAccent: UIColor = Colors.secondaryAccent
        public var tertiaryAccent: UIColor = Colors.tertiaryAccent
        public var quaternaryAccent: UIColor = Colors.quaternaryAccent
        public var quinaryAccent: UIColor = Colors.quinaryAccent
        
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
        public var textOnPrimary: UIColor = Colors.textOnPrimary
        
        public var stateError: UIColor = Colors.stateError
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
