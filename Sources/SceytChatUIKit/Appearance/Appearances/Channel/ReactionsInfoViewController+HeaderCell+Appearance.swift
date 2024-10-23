//
//  ReactionsInfoViewController+HeaderCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ReactionsInfoViewController.HeaderCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        selectedBackgroundColor: .accent,
        borderColor: .border,
        selectedBorderColor: .clear,
        borderWidth: 1,
        cornerRadius: 15,
        cornerCurve: .circular,
        labelAppearance: .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(14)
        ),
        selectedLabelAppearance: .init(
            foregroundColor: .onPrimary,
            font: Fonts.semiBold.withSize(14)
        )
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var selectedBackgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var borderColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var selectedBorderColor: UIColor
        
        @Trackable<Appearance, CGFloat>
        public var borderWidth: CGFloat
        
        @Trackable<Appearance, CGFloat>
        public var cornerRadius: CGFloat
        
        @Trackable<Appearance, CALayerCornerCurve>
        public var cornerCurve: CALayerCornerCurve
        
        @Trackable<Appearance, LabelAppearance>
        public var labelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var selectedLabelAppearance: LabelAppearance
        
        public init(
            backgroundColor: UIColor,
            selectedBackgroundColor: UIColor,
            borderColor: UIColor,
            selectedBorderColor: UIColor,
            borderWidth: CGFloat,
            cornerRadius: CGFloat,
            cornerCurve: CALayerCornerCurve,
            labelAppearance: LabelAppearance,
            selectedLabelAppearance: LabelAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._selectedBackgroundColor = Trackable(value: selectedBackgroundColor)
            self._borderColor = Trackable(value: borderColor)
            self._selectedBorderColor = Trackable(value: selectedBorderColor)
            self._borderWidth = Trackable(value: borderWidth)
            self._cornerRadius = Trackable(value: cornerRadius)
            self._cornerCurve = Trackable(value: cornerCurve)
            self._labelAppearance = Trackable(value: labelAppearance)
            self._selectedLabelAppearance = Trackable(value: selectedLabelAppearance)
        }
        
        public init(
            reference: ReactionsInfoViewController.HeaderCell.Appearance,
            backgroundColor: UIColor? = nil,
            selectedBackgroundColor: UIColor? = nil,
            borderColor: UIColor? = nil,
            selectedBorderColor: UIColor? = nil,
            borderWidth: CGFloat? = nil,
            cornerRadius: CGFloat? = nil,
            cornerCurve: CALayerCornerCurve? = nil,
            labelAppearance: LabelAppearance? = nil,
            selectedLabelAppearance: LabelAppearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._selectedBackgroundColor = Trackable(reference: reference, referencePath: \.selectedBackgroundColor)
            self._borderColor = Trackable(reference: reference, referencePath: \.borderColor)
            self._selectedBorderColor = Trackable(reference: reference, referencePath: \.selectedBorderColor)
            self._borderWidth = Trackable(reference: reference, referencePath: \.borderWidth)
            self._cornerRadius = Trackable(reference: reference, referencePath: \.cornerRadius)
            self._cornerCurve = Trackable(reference: reference, referencePath: \.cornerCurve)
            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
            self._selectedLabelAppearance = Trackable(reference: reference, referencePath: \.selectedLabelAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let selectedBackgroundColor { self.selectedBackgroundColor = selectedBackgroundColor }
            if let borderColor { self.borderColor = borderColor }
            if let selectedBorderColor { self.selectedBorderColor = selectedBorderColor }
            if let borderWidth { self.borderWidth = borderWidth }
            if let cornerRadius { self.cornerRadius = cornerRadius }
            if let cornerCurve { self.cornerCurve = cornerCurve }
            if let labelAppearance { self.labelAppearance = labelAppearance }
            if let selectedLabelAppearance { self.selectedLabelAppearance = selectedLabelAppearance }
        }
    }
}
