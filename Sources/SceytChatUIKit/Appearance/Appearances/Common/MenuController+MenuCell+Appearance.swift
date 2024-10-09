//
//  MenuController+MenuCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension MenuController.MenuCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .surface1,
        selectedBackgroundColor: .surface2,
        separatorColor: .border,
        imageTintColor: .primaryText,
        textColor: .primaryText,
        textFont: Fonts.regular.withSize(16),
        destructiveTextColor: .stateWarning,
        destructiveImageTintColor: .stateWarning
    )
    
    public class Appearance {
        @Trackable<Appearance, UIColor?>
        public var backgroundColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var selectedBackgroundColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var separatorColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var imageTintColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var textColor: UIColor?
        
        @Trackable<Appearance, UIFont?>
        public var textFont: UIFont?
        
        @Trackable<Appearance, UIColor?>
        public var destructiveTextColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var destructiveImageTintColor: UIColor?
        
        // Primary Initializer with all parameters
        public init(
            backgroundColor: UIColor,
            selectedBackgroundColor: UIColor,
            separatorColor: UIColor,
            imageTintColor: UIColor,
            textColor: UIColor,
            textFont: UIFont,
            destructiveTextColor: UIColor,
            destructiveImageTintColor: UIColor
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._selectedBackgroundColor = Trackable(value: selectedBackgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._imageTintColor = Trackable(value: imageTintColor)
            self._textColor = Trackable(value: textColor)
            self._textFont = Trackable(value: textFont)
            self._destructiveTextColor = Trackable(value: destructiveTextColor)
            self._destructiveImageTintColor = Trackable(value: destructiveImageTintColor)
        }
        
        // Secondary Initializer with optional parameters
        public init(
            reference: MenuController.MenuCell.Appearance,
            backgroundColor: UIColor? = nil,
            selectedBackgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            imageTintColor: UIColor? = nil,
            textColor: UIColor? = nil,
            textFont: UIFont? = nil,
            destructiveTextColor: UIColor? = nil,
            destructiveImageTintColor: UIColor? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._selectedBackgroundColor = Trackable(reference: reference, referencePath: \.selectedBackgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._imageTintColor = Trackable(reference: reference, referencePath: \.imageTintColor)
            self._textColor = Trackable(reference: reference, referencePath: \.textColor)
            self._textFont = Trackable(reference: reference, referencePath: \.textFont)
            self._destructiveTextColor = Trackable(reference: reference, referencePath: \.destructiveTextColor)
            self._destructiveImageTintColor = Trackable(reference: reference, referencePath: \.destructiveImageTintColor)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let selectedBackgroundColor { self.selectedBackgroundColor = selectedBackgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let imageTintColor { self.imageTintColor = imageTintColor }
            if let textColor { self.textColor = textColor }
            if let textFont { self.textFont = textFont }
            if let destructiveTextColor { self.destructiveTextColor = destructiveTextColor }
            if let destructiveImageTintColor { self.destructiveImageTintColor = destructiveImageTintColor }
        }
    }
}
