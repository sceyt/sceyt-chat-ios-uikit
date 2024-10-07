//
//  SeparatorHeaderView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SeparatorHeaderView: AppearanceProviding {
    public static var appearance = Appearance(
        title: nil,
        backgroundColor: .surface1,
        labelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(13)
        ),
        textAlignment: .left
    )
    
    public struct Appearance {
        @Trackable<Appearance, String?>
        public var title: String?
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var labelAppearance: LabelAppearance
        
        @Trackable<Appearance, NSTextAlignment>
        public var textAlignment: NSTextAlignment
        
        // Initializer with all parameters
        public init(
            title: String?,
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            textAlignment: NSTextAlignment
        ) {
            self._title = Trackable(value: title)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._labelAppearance = Trackable(value: labelAppearance)
            self._textAlignment = Trackable(value: textAlignment)
        }
        
        // Convenience initializer with optional parameters
        public init(
            reference: SeparatorHeaderView.Appearance,
            title: String? = nil,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance? = nil,
            textAlignment: NSTextAlignment? = nil
        ) {            
            self._title = Trackable(reference: reference, referencePath: \.title)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
            self._textAlignment = Trackable(reference: reference, referencePath: \.textAlignment)
            
            if let title { self.title = title }
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let labelAppearance { self.labelAppearance = labelAppearance }
            if let textAlignment { self.textAlignment = textAlignment }
        }
    }
}
