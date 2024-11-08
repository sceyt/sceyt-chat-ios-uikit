//
//  LabelAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct LabelAppearance {
    @Trackable<LabelAppearance, UIColor>
    public var foregroundColor: UIColor
    
    @Trackable<LabelAppearance, UIFont>
    public var font: UIFont
    
    @Trackable<LabelAppearance, UIColor>
    public var backgroundColor: UIColor
    
    // Initializer with default values
    public init(
        foregroundColor: UIColor,
        font: UIFont,
        backgroundColor: UIColor = .clear
    ) {
        self._foregroundColor = Trackable(value: foregroundColor)
        self._font = Trackable(value: font)
        self._backgroundColor = Trackable(value: backgroundColor)
    }
    
    // Convenience initializer for optional values
    public init(
        reference: LabelAppearance,
        foregroundColor: UIColor? = nil,
        font: UIFont? = nil,
        backgroundColor: UIColor? = nil
    ) {
        self._foregroundColor = Trackable(reference: reference, referencePath: \.foregroundColor)
        self._font = Trackable(reference: reference, referencePath: \.font)
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        
        if let foregroundColor { self.foregroundColor = foregroundColor }
        if let font { self.font = font }
        if let backgroundColor { self.backgroundColor = backgroundColor }
    }
}

public struct OptionalLabelAppearance {
    @Trackable<OptionalLabelAppearance, UIColor?>
    public var foregroundColor: UIColor?
    
    @Trackable<OptionalLabelAppearance, UIFont>
    public var font: UIFont
    
    @Trackable<OptionalLabelAppearance, UIColor>
    public var backgroundColor: UIColor
    
    // Initializer with default values
    public init(
        foregroundColor: UIColor?,
        font: UIFont,
        backgroundColor: UIColor = .clear
    ) {
        self._foregroundColor = Trackable(value: foregroundColor)
        self._font = Trackable(value: font)
        self._backgroundColor = Trackable(value: backgroundColor)
    }
    
    // Convenience initializer for optional values
    public init(
        reference: OptionalLabelAppearance,
        foregroundColor: UIColor? = nil,
        font: UIFont? = nil,
        backgroundColor: UIColor? = nil
    ) {
        self._foregroundColor = Trackable(reference: reference, referencePath: \.foregroundColor)
        self._font = Trackable(reference: reference, referencePath: \.font)
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        
        if let foregroundColor { self.foregroundColor = foregroundColor }
        if let font { self.font = font }
        if let backgroundColor { self.backgroundColor = backgroundColor }
    }
}
