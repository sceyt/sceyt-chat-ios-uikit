//
//  MessageInfoViewController+MarkerCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInfoViewController.MarkerCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance: CellAppearance<AnyUserFormatting, AnyDateFormatting, AnyUserAvatarProviding> {
        public lazy var backgroundColor: UIColor = .backgroundSections

        public init(
            backgroundColor: UIColor = .backgroundSections,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            subtitleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            titleFormatter: AnyUserFormatting = AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
            subtitleFormatter: AnyDateFormatting = AnyDateFormatting(SceytChatUIKit.shared.formatters.messageInfoDateFormatter),
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
        }
    }
}
