//
//  ChannelInfoViewController+OptionCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.OptionCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .backgroundSections
        public var titleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        )
        public var descriptionLabelAppearance: LabelAppearance? = nil
        public var switchTintColor: UIColor? = nil
        public var accessoryImage: UIImage? = nil
                
        public init(
            backgroundColor: UIColor = .backgroundSections,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.regular.withSize(16)
            ),
            descriptionLabelAppearance: LabelAppearance? = nil,
            switchTintColor: UIColor? = nil,
            accessoryImage: UIImage? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.titleLabelAppearance = titleLabelAppearance
            self.descriptionLabelAppearance = descriptionLabelAppearance
            self.switchTintColor = switchTintColor
            self.accessoryImage = accessoryImage
        }
    }
}
