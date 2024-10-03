//
//  SeparatorHeaderView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SeparatorHeaderView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var title: String? = nil
        public var backgroundColor: UIColor = .surface1
        public var labelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(13)
        )
        public var textAlignment: NSTextAlignment = .left
        
        // Initializer with default values
        public init(
            title: String? = nil,
            backgroundColor: UIColor = .surface1,
            labelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.semiBold.withSize(13)
            ),
            textAlignment: NSTextAlignment = .left
        ) {
            self.title = title
            self.backgroundColor = backgroundColor
            self.labelAppearance = labelAppearance
            self.textAlignment = textAlignment
        }
    }
}
