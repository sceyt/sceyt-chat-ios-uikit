//
//  TextInputAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class TextInputAppearance {
    public lazy var backgroundColor: UIColor = .background
    public lazy var labelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.regular.withSize(16))
    public lazy var placeholderAppearance: LabelAppearance = .init(foregroundColor: .footnoteText, font: Fonts.regular.withSize(16))
    public lazy var placeholder: String? = nil
    public lazy var tintColor: UIColor = .accent
    public lazy var cornerRadius: CGFloat = 18
    public lazy var cornerCurve: CALayerCornerCurve = .continuous
    public lazy var borderWidth: CGFloat = 0.5
    public lazy var borderColor: CGColor? = nil
    
    // Initializer with default values
    public init(
        backgroundColor: UIColor = .background,
        labelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                 font: Fonts.regular.withSize(16)),
        placeholderAppearance: LabelAppearance = .init(foregroundColor: .footnoteText,
                                                       font: Fonts.regular.withSize(16)),
        placeholder: String? = nil,
        tintColor: UIColor = .accent,
        cornerRadius: CGFloat = 18,
        cornerCurve: CALayerCornerCurve = .continuous,
        borderWidth: CGFloat = 0.5,
        borderColor: UIColor? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.labelAppearance = labelAppearance
        self.placeholderAppearance = placeholderAppearance
        self.placeholder = placeholder
        self.tintColor = tintColor
        self.cornerRadius = cornerRadius
        self.cornerCurve = cornerCurve
        self.borderWidth = borderWidth
        self.borderColor = borderColor?.cgColor
    }
}
