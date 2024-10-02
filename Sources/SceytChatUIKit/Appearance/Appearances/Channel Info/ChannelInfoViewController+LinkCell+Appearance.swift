//
//  ChannelInfoViewController+LinkCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.LinkCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var selectedBackgroundColor: UIColor = .surface2
        public lazy var linkLabelAppearance: LabelAppearance = .init(
            foregroundColor: .systemBlue,
            font: Fonts.regular.withSize(14)
        )
        public lazy var linkPreviewAppearance: LinkPreviewAppearance = .init(titleLabelAppearance: .init(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
                                                                             descriptionLabelAppearance: .init(
                                                                                foregroundColor: .secondaryText,
                                                                                font: Fonts.regular.withSize(13)
                                                                             ),
                                                                             placeholderIcon: .link)
        
        public init(
            selectedBackgroundColor: UIColor = .surface2,
            linkLabelAppearance: LabelAppearance = .init(
                foregroundColor: .systemBlue,
                font: Fonts.regular.withSize(14)
            ),
            linkPreviewAppearance: LinkPreviewAppearance = .init(titleLabelAppearance: .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
                                                                 descriptionLabelAppearance: .init(
                                                                    foregroundColor: .secondaryText,
                                                                    font: Fonts.regular.withSize(13)
                                                                 ),
                                                                 placeholderIcon: .link)
        ) {
            self.selectedBackgroundColor = selectedBackgroundColor
            self.linkLabelAppearance = linkLabelAppearance
            self.linkPreviewAppearance = linkPreviewAppearance
        }
    }
}
