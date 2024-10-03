//
//  MenuController+MenuCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension MenuController.MenuCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .surface1
        public var selectedBackgroundColor: UIColor? = .surface2
        public var separatorColor: UIColor? = .border
        public var imageTintColor: UIColor? = .primaryText
        public var textColor: UIColor? = .primaryText
        public var textFont: UIFont? = Fonts.regular.withSize(16)
        public var destructiveTextColor: UIColor? = .stateWarning
        public var destructiveImageTintColor: UIColor? = .stateWarning
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor? = .surface1,
            selectedBackgroundColor: UIColor? = .surface2,
            separatorColor: UIColor? = .border,
            imageTintColor: UIColor? = .primaryText,
            textColor: UIColor? = .primaryText,
            textFont: UIFont? = Fonts.regular.withSize(16),
            destructiveTextColor: UIColor? = .stateWarning,
            destructiveImageTintColor: UIColor? = .stateWarning
        ) {
            self.backgroundColor = backgroundColor
            self.selectedBackgroundColor = selectedBackgroundColor
            self.separatorColor = separatorColor
            self.imageTintColor = imageTintColor
            self.textColor = textColor
            self.textFont = textFont
            self.destructiveTextColor = destructiveTextColor
            self.destructiveImageTintColor = destructiveImageTintColor
        }
    }
}
