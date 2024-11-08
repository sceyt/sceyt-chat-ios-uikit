//
//  SheetViewController+Appearance.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 25.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SheetViewController: AppearanceProviding {
    public static var appearance = Appearance(
        overlayColor: .overlayBackground1,
        backgroundColor: .background,
        separatorColor: .border,
        titleLabelAppearance: .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(20)
        ),
        doneLabelAppearance: .init(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(16)
        )
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var overlayColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var doneLabelAppearance: LabelAppearance
        
        public init(
            overlayColor: UIColor,
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            doneLabelAppearance: LabelAppearance
        ) {
            self._overlayColor = Trackable(value: overlayColor)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._doneLabelAppearance = Trackable(value: doneLabelAppearance)
        }
        
        public init(
            reference: SheetViewController.Appearance,
            overlayColor: UIColor? = nil,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            doneLabelAppearance: LabelAppearance? = nil
        ) {
            self._overlayColor = Trackable(reference: reference, referencePath: \.overlayColor)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._doneLabelAppearance = Trackable(reference: reference, referencePath: \.doneLabelAppearance)
            
            if let overlayColor { self.overlayColor = overlayColor }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let doneLabelAppearance { self.doneLabelAppearance = doneLabelAppearance }
        }
    }
}
