//
//  ButtonAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class ButtonAppearance: AppearanceProviding {
    public var appearance: ButtonAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: ButtonAppearance?
    
    
    @Trackable<ButtonAppearance, LabelAppearance>
    public var labelAppearance: LabelAppearance
    
    @Trackable<ButtonAppearance, UIColor>
    public var backgroundColor: UIColor
    
    @Trackable<ButtonAppearance, CGFloat>
    public var cornerRadius: CGFloat
    
    @Trackable<ButtonAppearance, CALayerCornerCurve>
    public var cornerCurve: CALayerCornerCurve
    
    public static var appearance = ButtonAppearance(
        labelAppearance: .init(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(16)
        ),
        backgroundColor: .clear,
        cornerRadius: 0,
        cornerCurve: .continuous
    )
    
    // Initializer with default values
    public init(
        labelAppearance: LabelAppearance = .init(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(16)
        ),
        backgroundColor: UIColor = .clear,
        cornerRadius: CGFloat = 0,
        cornerCurve: CALayerCornerCurve = .continuous
    ) {
        self._labelAppearance = Trackable(value: labelAppearance)
        self._backgroundColor = Trackable(value: backgroundColor)
        self._cornerRadius = Trackable(value: cornerRadius)
        self._cornerCurve = Trackable(value: cornerCurve)
    }
    
    // Convenience initializer using reference appearance
    public init(
        reference: ButtonAppearance.AppearanceType,
        labelAppearance: LabelAppearance? = nil,
        backgroundColor: UIColor? = nil,
        cornerRadius: CGFloat? = nil,
        cornerCurve: CALayerCornerCurve? = nil
    ) {
        self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        self._cornerRadius = Trackable(reference: reference, referencePath: \.cornerRadius)
        self._cornerCurve = Trackable(reference: reference, referencePath: \.cornerCurve)
        
        if let labelAppearance { self.labelAppearance = labelAppearance }
        if let backgroundColor { self.backgroundColor = backgroundColor }
        if let cornerRadius { self.cornerRadius = cornerRadius }
        if let cornerCurve { self.cornerCurve = cornerCurve }
    }
}
