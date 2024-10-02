//
//  ChannelInfoViewController+DescriptionCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.DescriptionCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .backgroundSections
        public lazy var titleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        )
        public lazy var descriptionLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        )
        public lazy var titleText: String = L10n.Channel.Info.about
        
        public init(
            backgroundColor: UIColor = .backgroundSections,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            descriptionLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.regular.withSize(16)
            ),
            titleText: String = L10n.Channel.Info.about
        ) {
            self.backgroundColor = backgroundColor
            self.titleLabelAppearance = titleLabelAppearance
            self.descriptionLabelAppearance = descriptionLabelAppearance
            self.titleText = titleText
        }
    }
}
