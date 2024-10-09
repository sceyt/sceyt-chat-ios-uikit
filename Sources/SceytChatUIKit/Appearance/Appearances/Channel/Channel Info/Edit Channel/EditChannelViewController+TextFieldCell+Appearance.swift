//
//  EditChannelViewController+TextFieldCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelViewController.TextFieldCell: AppearanceProviding {
    public static var appearance = Appearance(
        separatorColor: .border,
        backgroundColor: .background,
        labelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        placeholderAppearance: LabelAppearance(
            foregroundColor: .footnoteText,
            font: Fonts.regular.withSize(16)
        ),
        placeholder: nil,
        tintColor: .accent,
        cornerRadius: 18,
        cornerCurve: .continuous,
        borderWidth: 0,
        borderColor: nil
    )

    public class Appearance: TextInputAppearance {
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        public init(
            separatorColor: UIColor,
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            placeholderAppearance: LabelAppearance,
            placeholder: String?,
            tintColor: UIColor,
            cornerRadius: CGFloat,
            cornerCurve: CALayerCornerCurve,
            borderWidth: CGFloat,
            borderColor: UIColor?
        ) {
            self._separatorColor = Trackable(value: separatorColor)
            super.init(
                backgroundColor: backgroundColor,
                labelAppearance: labelAppearance,
                placeholderAppearance: placeholderAppearance,
                placeholder: placeholder,
                tintColor: tintColor,
                cornerRadius: cornerRadius,
                cornerCurve: cornerCurve,
                borderWidth: borderWidth,
                borderColor: borderColor
            )
        }
        
        public init(
            reference: EditChannelViewController.TextFieldCell.Appearance,
            separatorColor: UIColor? = nil,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance? = nil,
            placeholderAppearance: LabelAppearance? = nil,
            placeholder: String? = nil,
            tintColor: UIColor? = nil,
            cornerRadius: CGFloat? = nil,
            cornerCurve: CALayerCornerCurve? = nil,
            borderWidth: CGFloat? = nil,
            borderColor: UIColor? = nil
        ) {
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            
            super.init(
                reference: Self.appearance,
                backgroundColor: backgroundColor,
                labelAppearance: labelAppearance,
                placeholderAppearance: placeholderAppearance,
                placeholder: placeholder,
                tintColor: tintColor,
                cornerRadius: cornerRadius,
                cornerCurve: cornerCurve,
                borderWidth: borderWidth,
                borderColor: borderColor
            )
            if let separatorColor { self.separatorColor = separatorColor }
        }
    }
}
