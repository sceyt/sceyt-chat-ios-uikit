//
//  Alert+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension Alert: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        separatorColor: .border,
        titleLabelAppearance: .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        messageLabelAppearance: .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        buttonAppearance: .init(
            labelAppearance: .init(
                foregroundColor: .accent,
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
                foregroundColor: .primaryText,
                font: Fonts.regular.withSize(16)
            ),
            tintColor: .primaryText,
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
        ),
        preferredActionFont: Fonts.semiBold.withSize(16)
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var messageLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, ButtonAppearance>
        public var buttonAppearance: ButtonAppearance
        
        @Trackable<Appearance, ButtonAppearance>
        public var cancelButtonAppearance: ButtonAppearance
        
        @Trackable<Appearance, ButtonAppearance>
        public var destructiveButtonAppearance: ButtonAppearance
        
        @Trackable<Appearance, UIFont>
        public var preferredActionFont: UIFont
        
        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            messageLabelAppearance: LabelAppearance,
            buttonAppearance: ButtonAppearance,
            cancelButtonAppearance: ButtonAppearance,
            destructiveButtonAppearance: ButtonAppearance,
            preferredActionFont: UIFont
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._messageLabelAppearance = Trackable(value: messageLabelAppearance)
            self._buttonAppearance = Trackable(value: buttonAppearance)
            self._cancelButtonAppearance = Trackable(value: cancelButtonAppearance)
            self._destructiveButtonAppearance = Trackable(value: destructiveButtonAppearance)
            self._preferredActionFont = Trackable(value: preferredActionFont)
        }
        
        public init(
            reference: Alert.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            messageLabelAppearance: LabelAppearance? = nil,
            buttonAppearance: ButtonAppearance? = nil,
            cancelButtonAppearance: ButtonAppearance? = nil,
            destructiveButtonAppearance: ButtonAppearance? = nil,
            preferredActionFont: UIFont? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._messageLabelAppearance = Trackable(reference: reference, referencePath: \.messageLabelAppearance)
            self._buttonAppearance = Trackable(reference: reference, referencePath: \.buttonAppearance)
            self._cancelButtonAppearance = Trackable(reference: reference, referencePath: \.cancelButtonAppearance)
            self._destructiveButtonAppearance = Trackable(reference: reference, referencePath: \.destructiveButtonAppearance)
            self._preferredActionFont = Trackable(reference: reference, referencePath: \.preferredActionFont)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let messageLabelAppearance { self.messageLabelAppearance = messageLabelAppearance }
            if let buttonAppearance { self.buttonAppearance = buttonAppearance }
            if let cancelButtonAppearance { self.cancelButtonAppearance = cancelButtonAppearance }
            if let destructiveButtonAppearance { self.destructiveButtonAppearance = destructiveButtonAppearance }
            if let preferredActionFont { self.preferredActionFont = preferredActionFont }
        }
    }
}
