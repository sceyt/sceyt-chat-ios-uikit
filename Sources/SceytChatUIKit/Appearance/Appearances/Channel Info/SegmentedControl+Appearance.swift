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
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .backgroundSections
        public lazy var labelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(16)
        )
        public lazy var selectedLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        )
        public lazy var separatorColor: UIColor = .border
        public lazy var indicatorColor: UIColor = .accent
        
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
