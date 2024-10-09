//
//  TextInputAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class TextInputAppearance: AppearanceProviding {
    
    public var appearance: TextInputAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: TextInputAppearance?
    
    public static var appearance = TextInputAppearance(
        backgroundColor: .background,
        labelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        placeholderAppearance: LabelAppearance(
            foregroundColor: .footnoteText,
            font: Fonts.regular.withSize(16)
        ),
        placeholder: nil,
        tintColor: .accent,
        cornerRadius: 18,
        cornerCurve: .continuous,
        borderWidth: 0,
        borderColor: nil
    )
    
    @Trackable<TextInputAppearance, UIColor>
    public var backgroundColor: UIColor
    
    @Trackable<TextInputAppearance, LabelAppearance>
    public var labelAppearance: LabelAppearance
    
    @Trackable<TextInputAppearance, LabelAppearance>
    public var placeholderAppearance: LabelAppearance
    
    @Trackable<TextInputAppearance, String?>
    public var placeholder: String?
    
    @Trackable<TextInputAppearance, UIColor>
    public var tintColor: UIColor
    
    @Trackable<TextInputAppearance, CGFloat>
    public var cornerRadius: CGFloat
    
    @Trackable<TextInputAppearance, CALayerCornerCurve>
    public var cornerCurve: CALayerCornerCurve
    
    @Trackable<TextInputAppearance, CGFloat>
    public var borderWidth: CGFloat
    
    @Trackable<TextInputAppearance, CGColor?>
    public var borderColor: CGColor?
    
    public init(
        backgroundColor: UIColor,
        labelAppearance: LabelAppearance,
        placeholderAppearance: LabelAppearance,
        placeholder: String?,
        tintColor: UIColor,
        cornerRadius: CGFloat,
        cornerCurve: CALayerCornerCurve,
        borderWidth: CGFloat,
        borderColor: UIColor?
    ) {
        self._backgroundColor = Trackable(value: backgroundColor)
        self._labelAppearance = Trackable(value: labelAppearance)
        self._placeholderAppearance = Trackable(value: placeholderAppearance)
        self._placeholder = Trackable(value: placeholder)
        self._tintColor = Trackable(value: tintColor)
        self._cornerRadius = Trackable(value: cornerRadius)
        self._cornerCurve = Trackable(value: cornerCurve)
        self._borderWidth = Trackable(value: borderWidth)
        self._borderColor = Trackable(value: borderColor?.cgColor)
    }
    
    public init(
        reference: TextInputAppearance,
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
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        self._labelAppearance = Trackable(reference: reference, referencePath: \.labelAppearance)
        self._placeholderAppearance = Trackable(reference: reference, referencePath: \.placeholderAppearance)
        self._placeholder = Trackable(reference: reference, referencePath: \.placeholder)
        self._tintColor = Trackable(reference: reference, referencePath: \.tintColor)
        self._cornerRadius = Trackable(reference: reference, referencePath: \.cornerRadius)
        self._cornerCurve = Trackable(reference: reference, referencePath: \.cornerCurve)
        self._borderWidth = Trackable(reference: reference, referencePath: \.borderWidth)
        self._borderColor = Trackable(reference: reference, referencePath: \.borderColor)
        
        if let backgroundColor { self.backgroundColor = backgroundColor }
        if let labelAppearance { self.labelAppearance = labelAppearance }
        if let placeholderAppearance { self.placeholderAppearance = placeholderAppearance }
        if let placeholder { self.placeholder = placeholder }
        if let tintColor { self.tintColor = tintColor }
        if let cornerRadius { self.cornerRadius = cornerRadius }
        if let cornerCurve { self.cornerCurve = cornerCurve }
        if let borderWidth { self.borderWidth = borderWidth }
        if let borderColor { self.borderColor = borderColor.cgColor }
    }
}
