//
//  UserCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension UserCell: AppearanceProviding {
    public static var appearance = Appearance()
#warning("change fromatters")
    public class Appearance: CellAppearance<AnyChannelFormatting, AnyChannelFormatting, AnyChannelAvatarProviding> {
        public var backgroundColor: UIColor
        public var separatorColor: UIColor
        
        // Initializer with type-erased formatters and providers
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
            self.backgroundColor = backgroundColor
            self.separatorColor = separatorColor
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                avatarProvider: avatarProvider
            )
        }
    }
}
