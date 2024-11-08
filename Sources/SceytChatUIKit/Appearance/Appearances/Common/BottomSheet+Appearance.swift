//
//  BottomSheet+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

extension BottomSheet: AppearanceProviding {
    
    public static var appearance = Appearance(
        backgroundColor: .background,
        separatorColor: .border,
        titleLabelAppearance: .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(14)
        ),
        buttonAppearance: .init(
            labelAppearance: .init(
                foregroundColor: .primaryText,
                font: Fonts.regular.withSize(16)
            ),
            tintColor: .accent,
            backgroundColor: .background,
            highlightedBackgroundColor: .surface2,
            cornerRadius: 0,
            cornerCurve: .continuous
        ),
        cancelButtonAppearance: .init(
            labelAppearance: .init(
                foregroundColor: .accent,
                font: Fonts.semiBold.withSize(18)
            ),
            tintColor: .accent,
            backgroundColor: .background,
            highlightedBackgroundColor: .surface2,
            cornerRadius: 0,
            cornerCurve: .continuous
        ),
        destructiveButtonAppearance: .init(
            labelAppearance: .init(
                foregroundColor: .stateWarning,
                font: Fonts.regular.withSize(16)
            ),
            tintColor: .stateWarning,
            backgroundColor: .background,
            highlightedBackgroundColor: .surface2,
            cornerRadius: 0,
            cornerCurve: .continuous
        )
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, ButtonAppearance>
        public var buttonAppearance: ButtonAppearance
        
        @Trackable<Appearance, ButtonAppearance>
        public var cancelButtonAppearance: ButtonAppearance
        
        @Trackable<Appearance, ButtonAppearance>
        public var destructiveButtonAppearance: ButtonAppearance
        
        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            buttonAppearance: ButtonAppearance,
            cancelButtonAppearance: ButtonAppearance,
            destructiveButtonAppearance: ButtonAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._buttonAppearance = Trackable(value: buttonAppearance)
            self._cancelButtonAppearance = Trackable(value: cancelButtonAppearance)
            self._destructiveButtonAppearance = Trackable(value: destructiveButtonAppearance)
        }
        
        public init(
            reference: BottomSheet.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            buttonAppearance: ButtonAppearance? = nil,
            cancelButtonAppearance: ButtonAppearance? = nil,
            destructiveButtonAppearance: ButtonAppearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._buttonAppearance = Trackable(reference: reference, referencePath: \.buttonAppearance)
            self._cancelButtonAppearance = Trackable(reference: reference, referencePath: \.cancelButtonAppearance)
            self._destructiveButtonAppearance = Trackable(reference: reference, referencePath: \.destructiveButtonAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let buttonAppearance { self.buttonAppearance = buttonAppearance }
            if let cancelButtonAppearance { self.cancelButtonAppearance = cancelButtonAppearance }
            if let destructiveButtonAppearance { self.destructiveButtonAppearance = destructiveButtonAppearance }
        }
    }
}
