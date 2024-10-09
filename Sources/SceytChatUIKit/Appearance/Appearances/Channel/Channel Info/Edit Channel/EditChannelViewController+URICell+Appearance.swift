//
//  EditChannelViewController+URICell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelViewController.URICell: AppearanceProviding {
    public static var appearance = Appearance(
        separatorColor: .border,
        prefixLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        )
    )
    
    public class Appearance: TextInputAppearance {
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var prefixLabelAppearance: LabelAppearance
        
        public init(
            separatorColor: UIColor,
            prefixLabelAppearance: LabelAppearance
        ) {
            self._separatorColor = Trackable(value: separatorColor)
            self._prefixLabelAppearance = Trackable(value: prefixLabelAppearance)
            
            super.init(
                reference: TextInputAppearance.appearance,
                backgroundColor: .backgroundSections,
                labelAppearance: LabelAppearance(
                    foregroundColor: .primaryText,
                    font: Fonts.regular.withSize(16)
                ),
                placeholderAppearance: LabelAppearance(
                    foregroundColor: .secondaryText,
                    font: Fonts.regular.withSize(16)
                )
            )
        }
        
        public init(
            reference: EditChannelViewController.URICell.Appearance,
            separatorColor: UIColor? = nil,
            prefixLabelAppearance: LabelAppearance? = nil,
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
            self._prefixLabelAppearance = Trackable(reference: reference, referencePath: \.prefixLabelAppearance)
            
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
            if let prefixLabelAppearance { self.prefixLabelAppearance = prefixLabelAppearance }
        }
    }
}
