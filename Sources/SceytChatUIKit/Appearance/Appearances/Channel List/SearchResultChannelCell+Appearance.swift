//
//  SearchResultChannelCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SearchResultChannelCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance: ItemAppearance<AnyChannelFormatting, AnyChannelFormatting, AnyChannelAvatarProviding> {
        public lazy var backgroundColor: UIColor = .clear
        public lazy var separatorColor: UIColor = .border
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .clear,
            separatorColor: UIColor = .border,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            subtitleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            titleFormatter: AnyChannelFormatting = AnyChannelFormatting(SceytChatUIKit.shared.formatters.channelNameFormatter),
            subtitleFormatter: AnyChannelFormatting = AnyChannelFormatting(SceytChatUIKit.shared.formatters.channelSubtitleFormatter),
            avatarProvider: AnyChannelAvatarProviding = AnyChannelAvatarProviding(SceytChatUIKit.shared.visualProviders.channelAvatarProvider)
        ) {
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                avatarProvider: avatarProvider
            )
            
            self.backgroundColor = backgroundColor
            self.separatorColor = separatorColor
        }
    }
}
