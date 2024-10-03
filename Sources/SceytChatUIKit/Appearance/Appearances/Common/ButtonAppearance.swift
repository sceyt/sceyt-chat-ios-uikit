//
//  ButtonAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct ButtonAppearance {
    public var labelAppearance: LabelAppearance = .init(
        foregroundColor: .accent,
        font: Fonts.semiBold.withSize(16)
    )
    public var backgroundColor: UIColor = .clear
    public var cornerRadius: CGFloat = 0
    public var cornerCurve: CALayerCornerCurve = .continuous
    
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
        self.labelAppearance = labelAppearance
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.cornerCurve = cornerCurve
    }
}
