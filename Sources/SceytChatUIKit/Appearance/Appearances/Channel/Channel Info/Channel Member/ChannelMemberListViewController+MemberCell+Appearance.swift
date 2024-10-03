//
//  ChannelMemberListViewController+MemberCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelMemberListViewController.MemberCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance: CellAppearance<AnyUserFormatting, AnyUserFormatting, AnyUserAvatarProviding> {
        public var backgroundColor: UIColor = .background
        public var separatorColor: UIColor = UIColor.border
        public var roleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        )
        
        public init(
            backgroundColor: UIColor = .background,
            separatorColor: UIColor = UIColor.border,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            subtitleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            roleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            titleFormatter: AnyUserFormatting = AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
            subtitleFormatter: AnyUserFormatting = AnyUserFormatting(SceytChatUIKit.shared.formatters.userPresenceDateFormatter),
            visualProvider: AnyUserAvatarProviding = AnyUserAvatarProviding(SceytChatUIKit.shared.visualProviders.userAvatarProvider)
        ) {
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                visualProvider: visualProvider
            )
            self.backgroundColor = backgroundColor
            self.separatorColor = separatorColor
            self.roleLabelAppearance = roleLabelAppearance
        }
    }
}
