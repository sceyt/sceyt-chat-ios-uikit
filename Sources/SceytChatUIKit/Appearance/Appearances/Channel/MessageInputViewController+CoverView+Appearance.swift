//
//  MessageInputViewController+CoverView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.CoverView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .background
        public lazy var labelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                 font: Fonts.regular.withSize(16))
        public lazy var separatorColor: UIColor = .border
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .background,
            labelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                     font: Fonts.regular.withSize(16)),
            separatorColor: UIColor = .border
        ) {
            self.backgroundColor = backgroundColor
            self.labelAppearance = labelAppearance
            self.separatorColor = separatorColor
        }
    }
}
