//
//  EmojiPickerViewController+SectionHeaderView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EmojiPickerViewController.SectionHeaderView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .clear,
        labelAppearance: .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(12)
        )
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var labelAppearance: LabelAppearance
        
        public init(
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._labelAppearance = Trackable(value: labelAppearance)
        }
        
        public init(
            reference: EmojiPickerViewController.SectionHeaderView.Appearance,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let labelAppearance { self.labelAppearance = labelAppearance }
        }
    }
}
