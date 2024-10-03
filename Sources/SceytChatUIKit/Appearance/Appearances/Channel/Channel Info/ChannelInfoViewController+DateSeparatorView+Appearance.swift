//
//  ChannelInfoViewController+DateSeparatorView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.DateSeparatorView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .surface1
        public var labelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(13)
        )
        public var dateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.channelInfoAttachmentSeparatorDateFormatter
        
        public init(
            backgroundColor: UIColor = .surface1,
            labelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.semiBold.withSize(13)
            ),
            dateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.channelInfoAttachmentSeparatorDateFormatter
        ) {
            self.backgroundColor = backgroundColor
            self.labelAppearance = labelAppearance
            self.dateFormatter = dateFormatter
        }
    }
}
