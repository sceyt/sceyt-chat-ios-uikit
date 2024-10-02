//
//  ChannelInfoViewController+DetailsCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.DetailsCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .backgroundSections
        public lazy var titleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.bold.withSize(20)
        )
        public lazy var subtitleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(16)
        )
        public lazy var channelDefaultAvatarProvider: any ChannelAvatarProviding = SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider
        public lazy var channelNameFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelNameFormatter
        public lazy var channelSubtitleFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelSubtitleFormatter
        
        public init(
            backgroundColor: UIColor = .backgroundSections,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.bold.withSize(20)
            ),
            subtitleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(16)
            ),
            channelDefaultAvatarProvider: any ChannelAvatarProviding = SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider,
            channelNameFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelNameFormatter,
            channelSubtitleFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelSubtitleFormatter
        ) {
            self.backgroundColor = backgroundColor
            self.titleLabelAppearance = titleLabelAppearance
            self.subtitleLabelAppearance = subtitleLabelAppearance
            self.channelDefaultAvatarProvider = channelDefaultAvatarProvider
            self.channelNameFormatter = channelNameFormatter
            self.channelSubtitleFormatter = channelSubtitleFormatter
        }
    }
}
