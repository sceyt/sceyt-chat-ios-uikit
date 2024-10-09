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
        public var colors: Colors
        
        public init(
            colors: Theme.Colors = Colors()
        ) {
            self.colors = colors
        }
    }
}

public extension SceytChatUIKit.Theme {
    
    public struct Colors {
        public let accent: UIColor
        public let accent2: UIColor
        public let accent3: UIColor
        public let accent4: UIColor
        public let accent5: UIColor
        
        public let surface1: UIColor
        public let surface2: UIColor
        public let surface3: UIColor
        
        public let background: UIColor
        public let backgroundSecondary: UIColor
        public let backgroundSections: UIColor
        public let backgroundDark: UIColor
        public let border: UIColor
        public let iconInactive: UIColor
        public let iconSecondary: UIColor
        public let overlayBackground1: UIColor
        public let overlayBackground2: UIColor
        
        public let primaryText: UIColor
        public let secondaryText: UIColor
        public let footnoteText: UIColor
        public let onPrimary: UIColor
        
        public let stateWarning: UIColor
        public let stateSuccess: UIColor
        public let stateAttention: UIColor
        
        public init(
            accent: UIColor = DefaultColors.accent,
            accent2: UIColor = DefaultColors.accent2,
            accent3: UIColor = DefaultColors.accent3,
            accent4: UIColor = DefaultColors.accent4,
            accent5: UIColor = DefaultColors.accent5,
            surface1: UIColor = DefaultColors.surface1,
            surface2: UIColor = DefaultColors.surface2,
            surface3: UIColor = DefaultColors.surface3,
            background: UIColor = DefaultColors.background,
            backgroundSecondary: UIColor = DefaultColors.backgroundSecondary,
            backgroundSections: UIColor = DefaultColors.backgroundSections,
            backgroundDark: UIColor = DefaultColors.backgroundDark,
            border: UIColor = DefaultColors.border,
            iconInactive: UIColor = DefaultColors.iconInactive,
            iconSecondary: UIColor = DefaultColors.iconSecondary,
            overlayBackground1: UIColor = DefaultColors.overlayBackground1,
            overlayBackground2: UIColor = DefaultColors.overlayBackground2,
            primaryText: UIColor = DefaultColors.primaryText,
            secondaryText: UIColor = DefaultColors.secondaryText,
            footnoteText: UIColor = DefaultColors.footnoteText,
            onPrimary: UIColor = DefaultColors.onPrimary,
            stateWarning: UIColor = DefaultColors.defaultRed,
            stateSuccess: UIColor = DefaultColors.stateSuccess,
            stateAttention: UIColor = DefaultColors.stateAttention
        ) {
            self.accent = accent
            self.accent2 = accent2
            self.accent3 = accent3
            self.accent4 = accent4
            self.accent5 = accent5
            self.surface1 = surface1
            self.surface2 = surface2
            self.surface3 = surface3
            self.background = background
            self.backgroundSecondary = backgroundSecondary
            self.backgroundSections = backgroundSections
            self.backgroundDark = backgroundDark
            self.border = border
            self.iconInactive = iconInactive
            self.iconSecondary = iconSecondary
            self.overlayBackground1 = overlayBackground1
            self.overlayBackground2 = overlayBackground2
            self.primaryText = primaryText
            self.secondaryText = secondaryText
            self.footnoteText = footnoteText
            self.onPrimary = onPrimary
            self.stateWarning = stateWarning
            self.stateSuccess = stateSuccess
            self.stateAttention = stateAttention
        }
    }
}
