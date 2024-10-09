//
//  BottomSheet+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension BottomSheet: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColors: (normal: UIColor, highlighted: UIColor)? = (.background, .surface2)
        public var titleFont: UIFont? = Fonts.semiBold.withSize(14)
        public var titleColor: UIColor? = .secondaryText
        public var buttonFont: UIFont? = Fonts.regular.withSize(16)
        public var normalTextColor: UIColor? = .primaryText
        public var normalIconColor: UIColor? = .accent
        public var destructiveTextColor: UIColor? = .stateWarning
        public var destructiveIconColor: UIColor? = .stateWarning
        public var cancelFont: UIFont? = Fonts.semiBold.withSize(18)
        public var cancelTextColor: UIColor? = .accent
        public var separatorColor: UIColor? = .border
        
        // Initializer with default values
        public init(
            backgroundColors: (normal: UIColor, highlighted: UIColor)? = (.background, .surface2),
            titleFont: UIFont? = Fonts.semiBold.withSize(14),
            titleColor: UIColor? = .secondaryText,
            buttonFont: UIFont? = Fonts.regular.withSize(16),
            normalTextColor: UIColor? = .primaryText,
            normalIconColor: UIColor? = .accent,
            destructiveTextColor: UIColor? = .stateWarning,
            destructiveIconColor: UIColor? = .stateWarning,
            cancelFont: UIFont? = Fonts.semiBold.withSize(18),
            cancelTextColor: UIColor? = .accent,
            separatorColor: UIColor? = .border
        ) {
            self.backgroundColors = backgroundColors
            self.titleFont = titleFont
            self.titleColor = titleColor
            self.buttonFont = buttonFont
            self.normalTextColor = normalTextColor
            self.normalIconColor = normalIconColor
            self.destructiveTextColor = destructiveTextColor
            self.destructiveIconColor = destructiveIconColor
            self.cancelFont = cancelFont
            self.cancelTextColor = cancelTextColor
            self.separatorColor = separatorColor
        }
    }
}
