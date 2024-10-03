//
//  MessageInputViewController+MessageSearchControlsView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController.MessageSearchControlsView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var separatorColor: UIColor? = .border
        public var backgroundColor: UIColor? = .background
        public var previousIcon: UIImage = .chevronUp
        public var nextIcon: UIImage = .chevronDown
        public var resultLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        )
        
        // Initializer with default values
        public init(
            separatorColor: UIColor? = .border,
            backgroundColor: UIColor? = .background,
            previousIcon: UIImage = .chevronUp,
            nextIcon: UIImage = .chevronDown,
            resultLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.regular.withSize(16)
            )
        ) {
            self.separatorColor = separatorColor
            self.backgroundColor = backgroundColor
            self.previousIcon = previousIcon
            self.nextIcon = nextIcon
            self.resultLabelAppearance = resultLabelAppearance
        }
    }
}
