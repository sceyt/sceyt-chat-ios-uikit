//
//  MessageInputViewController+CoverView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.CoverView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        labelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        separatorColor: .border
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var labelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            separatorColor: UIColor
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._labelAppearance = Trackable(value: labelAppearance)
            self._separatorColor = Trackable(value: separatorColor)
        }
        
        public init(
            reference: MessageInputViewController.CoverView.Appearance,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance? = nil,
            separatorColor: UIColor? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let labelAppearance { self.labelAppearance = labelAppearance }
            if let separatorColor { self.separatorColor = separatorColor }
        }
    }
}
