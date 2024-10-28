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
        labelAppearance: .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        destructiveLabelAppearance: .init(
            foregroundColor: .stateWarning,
            font: Fonts.regular.withSize(16)
        ),
        destructiveImageTintColor: .stateWarning
    )
    
    public class Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var selectedBackgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var imageTintColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var labelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var destructiveLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIColor>
        public var destructiveImageTintColor: UIColor
        
        // Primary Initializer with all parameters
        public init(
            backgroundColor: UIColor,
            selectedBackgroundColor: UIColor,
            separatorColor: UIColor,
            imageTintColor: UIColor,
            labelAppearance: LabelAppearance,
            destructiveLabelAppearance: LabelAppearance,
            destructiveImageTintColor: UIColor
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._selectedBackgroundColor = Trackable(value: selectedBackgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._imageTintColor = Trackable(value: imageTintColor)
            self._labelAppearance = Trackable(value: labelAppearance)
            self._destructiveLabelAppearance = Trackable(value: destructiveLabelAppearance)
            self._destructiveImageTintColor = Trackable(value: destructiveImageTintColor)
        }
        
        // Secondary Initializer with optional parameters
        public init(
            reference: MenuController.MenuCell.Appearance,
            backgroundColor: UIColor? = nil,
            selectedBackgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            imageTintColor: UIColor? = nil,
            labelAppearance: LabelAppearance? = nil,
            destructiveLabelAppearance: LabelAppearance? = nil,
            destructiveImageTintColor: UIColor? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._selectedBackgroundColor = Trackable(reference: reference, referencePath: \.selectedBackgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._imageTintColor = Trackable(reference: reference, referencePath: \.imageTintColor)
            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
            self._destructiveLabelAppearance = Trackable(reference: reference, referencePath: \.destructiveLabelAppearance)
            self._destructiveImageTintColor = Trackable(reference: reference, referencePath: \.destructiveImageTintColor)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let selectedBackgroundColor { self.selectedBackgroundColor = selectedBackgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let imageTintColor { self.imageTintColor = imageTintColor }
            if let labelAppearance { self.labelAppearance = labelAppearance }
            if let destructiveLabelAppearance { self.destructiveLabelAppearance = destructiveLabelAppearance }
            if let destructiveImageTintColor { self.destructiveImageTintColor = destructiveImageTintColor }
        }
    }
}
