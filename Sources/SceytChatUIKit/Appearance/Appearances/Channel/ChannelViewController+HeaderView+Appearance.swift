//
//  ChannelViewController+HeaderView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController.HeaderView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var titleLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                      font: Fonts.semiBold.withSize(19))
        public lazy var subtitleLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                         font: Fonts.regular.withSize(13))
        public lazy var titleFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelNameFormatter
        public lazy var subtitleFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelSubtitleFormatter
        public lazy var typingUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.typingUserNameFormatter
        public lazy var avatarProvider: any ChannelAvatarProviding = SceytChatUIKit.shared.visualProviders.channelAvatarProvider
        
        // Initializer with default values
        public init(
            titleLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                          font: Fonts.semiBold.withSize(19)),
            subtitleLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                             font: Fonts.regular.withSize(13)),
            titleFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelNameFormatter,
            subtitleFormatter: any ChannelFormatting = SceytChatUIKit.shared.formatters.channelSubtitleFormatter,
            typingUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.typingUserNameFormatter,
            avatarProvider: any ChannelAvatarProviding = SceytChatUIKit.shared.visualProviders.channelAvatarProvider
        ) {
            self.titleLabelAppearance = titleLabelAppearance
            self.subtitleLabelAppearance = subtitleLabelAppearance
            self.titleFormatter = titleFormatter
            self.subtitleFormatter = subtitleFormatter
            self.typingUserNameFormatter = typingUserNameFormatter
            self.avatarProvider = avatarProvider
        }
    }
}
