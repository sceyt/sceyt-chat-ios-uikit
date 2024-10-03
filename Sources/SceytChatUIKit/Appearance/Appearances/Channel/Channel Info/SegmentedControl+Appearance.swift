//
//  SegmentedControl+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SegmentedControl: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .backgroundSections
        public var labelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(16)
        )
        public var selectedLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        )
        public var separatorColor: UIColor = .border
        public var indicatorColor: UIColor = .accent
        
        public init(
            backgroundColor: UIColor = .backgroundSections,
            labelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            selectedLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            separatorColor: UIColor = .border,
            indicatorColor: UIColor = .accent
        ) {
            self.backgroundColor = backgroundColor
            self.labelAppearance = labelAppearance
            self.selectedLabelAppearance = selectedLabelAppearance
            self.separatorColor = separatorColor
            self.indicatorColor = indicatorColor
        }
    }
}
