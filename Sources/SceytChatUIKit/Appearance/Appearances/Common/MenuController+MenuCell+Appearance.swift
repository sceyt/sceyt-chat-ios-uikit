//
//  MenuController+MenuCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension MenuController.MenuCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor? = .surface1
        public lazy var selectedBackgroundColor: UIColor? = .surface2
        public lazy var separatorColor: UIColor? = .border
        public lazy var imageTintColor: UIColor? = .primaryText
        public lazy var textColor: UIColor? = .primaryText
        public lazy var textFont: UIFont? = Fonts.regular.withSize(16)
        public lazy var destructiveTextColor: UIColor? = .stateWarning
        public lazy var destructiveImageTintColor: UIColor? = .stateWarning
        
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
