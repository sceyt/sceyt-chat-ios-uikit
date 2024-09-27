//
//  ButtonAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class ButtonAppearance {
    public lazy var labelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                             font: Fonts.semiBold.withSize(16))
    public lazy var backgroundColor: UIColor? = nil
    public lazy var cornerRadius: CGFloat = 0
    public lazy var cornerCurve: CALayerCornerCurve = .continuous
    
    // Initializer with default values
    public init(
        labelAppearance: LabelAppearance = .init(foregroundColor: .accent, font: Fonts.semiBold.withSize(16)),
        backgroundColor: UIColor? = nil,
        cornerRadius: CGFloat = 0,
        cornerCurve: CALayerCornerCurve = .continuous
    ) {
        self.labelAppearance = labelAppearance
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.cornerCurve = cornerCurve
    }
}
