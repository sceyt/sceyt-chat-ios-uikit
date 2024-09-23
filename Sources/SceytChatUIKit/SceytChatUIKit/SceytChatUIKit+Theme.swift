//
//  SceytChatUIKit+Theme.swift
//
//
//  Created by Arthur Avagyan on 07.08.24.
//

import UIKit
import SceytChat

public extension SceytChatUIKit {
    
    public struct Theme {
        public var colors = Colors()
    }
}

public extension SceytChatUIKit.Theme {
    
    public struct Colors {
        public var accent: UIColor = DefaultColors.accent
        public var accent2: UIColor = DefaultColors.accent2
        public var accent3: UIColor = DefaultColors.accent3
        public var accent4: UIColor = DefaultColors.accent4
        public var accent5: UIColor = DefaultColors.accent5
        
        public var surface1: UIColor = DefaultColors.surface1
        public var surface2: UIColor = DefaultColors.surface2
        public var surface3: UIColor = DefaultColors.surface3
        
        public var background: UIColor = DefaultColors.background
        public var backgroundSecondary: UIColor = DefaultColors.backgroundSecondary
        public var backgroundSections: UIColor = DefaultColors.backgroundSections
        public var backgroundDark: UIColor = DefaultColors.backgroundDark
        public var border: UIColor = DefaultColors.border
        public var iconInactive: UIColor = DefaultColors.iconInactive
        public var iconSecondary: UIColor = DefaultColors.iconSecondary
        public var overlayBackground1: UIColor = DefaultColors.overlayBackground1
        public var overlayBackground2: UIColor = DefaultColors.overlayBackground2
        
        public var primaryText: UIColor = DefaultColors.primaryText
        public var secondaryText: UIColor = DefaultColors.secondaryText
        public var footnoteText: UIColor = DefaultColors.footnoteText
        public var onPrimary: UIColor = DefaultColors.onPrimary
        
        public var stateWarning: UIColor = DefaultColors.stateWarning
        public var stateSuccess: UIColor = DefaultColors.stateSuccess
        public var stateAttention: UIColor = DefaultColors.stateAttention
    }
}

public extension SceytChatUIKit.Theme.Colors {
    
    public func with(
        _ populator: (inout Self) throws -> ()
    ) rethrows -> Self {
        var message = self
        try populator(&message)
        return message
    }
}

public extension SceytChatUIKit.Theme {
    
    public func with(
        _ populator: (inout Self) throws -> ()
    ) rethrows -> Self {
        var message = self
        try populator(&message)
        return message
    }
}
