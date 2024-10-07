//
//  SegmentedControl+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SegmentedControl: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .backgroundSections,
        labelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        selectedLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        separatorColor: .border,
        indicatorColor: .accent
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var labelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var selectedLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var indicatorColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            selectedLabelAppearance: LabelAppearance,
            separatorColor: UIColor,
            indicatorColor: UIColor
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._labelAppearance = Trackable(value: labelAppearance)
            self._selectedLabelAppearance = Trackable(value: selectedLabelAppearance)
            self._separatorColor = Trackable(value: separatorColor)
            self._indicatorColor = Trackable(value: indicatorColor)
        }
        
        public init(
            reference: SegmentedControl.Appearance,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance? = nil,
            selectedLabelAppearance: LabelAppearance? = nil,
            separatorColor: UIColor? = nil,
            indicatorColor: UIColor? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
            self._selectedLabelAppearance = Trackable(reference: reference, referencePath: \.selectedLabelAppearance)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._indicatorColor = Trackable(reference: reference, referencePath: \.indicatorColor)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let labelAppearance { self.labelAppearance = labelAppearance }
            if let selectedLabelAppearance { self.selectedLabelAppearance = selectedLabelAppearance }
            if let separatorColor { self.separatorColor = separatorColor }
            if let indicatorColor { self.indicatorColor = indicatorColor }
        }
    }
}
