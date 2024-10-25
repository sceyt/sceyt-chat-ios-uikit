//
//  ButtonAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class ButtonAppearance: AppearanceProviding {
    
    public static var appearance = ButtonAppearance(
        labelAppearance: .init(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(16)
        ),
        tintColor: .accent,
        backgroundColor: .clear,
        highlightedBackgroundColor: .clear,
        cornerRadius: 0,
        cornerCurve: .continuous
    )
    
    public var appearance: ButtonAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: ButtonAppearance?
    
    
    @Trackable<ButtonAppearance, LabelAppearance>
    public var labelAppearance: LabelAppearance
    
    @Trackable<ButtonAppearance, UIColor>
    public var tintColor: UIColor
    
    @Trackable<ButtonAppearance, UIColor>
    public var backgroundColor: UIColor
    
    @Trackable<ButtonAppearance, UIColor>
    public var highlightedBackgroundColor: UIColor
    
    @Trackable<ButtonAppearance, CGFloat>
    public var cornerRadius: CGFloat
    
    @Trackable<ButtonAppearance, CALayerCornerCurve>
    public var cornerCurve: CALayerCornerCurve
    
    // Initializer with default values
    public init(
        labelAppearance: LabelAppearance,
        tintColor: UIColor,
        backgroundColor: UIColor,
        highlightedBackgroundColor: UIColor,
        cornerRadius: CGFloat,
        cornerCurve: CALayerCornerCurve
    ) {
        self._labelAppearance = Trackable(value: labelAppearance)
        self._tintColor = Trackable(value: tintColor)
        self._backgroundColor = Trackable(value: backgroundColor)
        self._highlightedBackgroundColor = Trackable(value: highlightedBackgroundColor)
        self._cornerRadius = Trackable(value: cornerRadius)
        self._cornerCurve = Trackable(value: cornerCurve)
    }
    
    // Convenience initializer using reference appearance
    public init(
        reference: ButtonAppearance,
        labelAppearance: LabelAppearance? = nil,
        tintColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        highlightedBackgroundColor: UIColor? = nil,
        cornerRadius: CGFloat? = nil,
        cornerCurve: CALayerCornerCurve? = nil
    ) {
        self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
        self._tintColor = Trackable(reference: reference, referencePath: \.tintColor)
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        self._highlightedBackgroundColor = Trackable(reference: reference, referencePath: \.highlightedBackgroundColor)
        self._cornerRadius = Trackable(reference: reference, referencePath: \.cornerRadius)
        self._cornerCurve = Trackable(reference: reference, referencePath: \.cornerCurve)
        
        if let labelAppearance { self.labelAppearance = labelAppearance }
        if let tintColor { self.tintColor = tintColor }
        if let backgroundColor { self.backgroundColor = backgroundColor }
        if let highlightedBackgroundColor { self.highlightedBackgroundColor = highlightedBackgroundColor }
        if let cornerRadius { self.cornerRadius = cornerRadius }
        if let cornerCurve { self.cornerCurve = cornerCurve }
    }
}
