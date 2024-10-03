//
//  MessageInputViewController+MentionUsersListViewController+MentionUserCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24.
//

import UIKit

extension MessageInputViewController.MentionUsersListViewController.MentionUserCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance: CellAppearance<AnyUserFormatting, EmptyFormatter, AnyUserAvatarProviding> {
        public var presenceStateIconProvider: any PresenceStateIconProviding = SceytChatUIKit.shared.visualProviders.presenceStateIconProvider
        
        // Initializer with default values
        public init(
            presenceStateIconProvider: any PresenceStateIconProviding = SceytChatUIKit.shared.visualProviders.presenceStateIconProvider,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            titleFormatter: AnyUserFormatting = AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
            visualProvider: AnyUserAvatarProviding = AnyUserAvatarProviding(SceytChatUIKit.shared.visualProviders.userAvatarProvider)
        ) {
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: nil,
                titleFormatter: titleFormatter,
                subtitleFormatter: EmptyFormatter(),
                visualProvider: visualProvider
            )
            
            self.presenceStateIconProvider = presenceStateIconProvider
        }
    }
}
