//
//  MessageInputViewController+MentionUsersListViewController+MentionUserCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24.
//

import UIKit

extension MessageInputViewController.MentionUsersListViewController.MentionUserCell: AppearanceProviding {
    public static var appearance = Appearance(
        presenceStateIconProvider: SceytChatUIKit.shared.visualProviders.presenceStateIconProvider,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        titleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
        visualProvider: AnyUserAvatarProviding(SceytChatUIKit.shared.visualProviders.userAvatarProvider)
    )
    
    public class Appearance: CellAppearance<AnyUserFormatting, EmptyFormatter, AnyUserAvatarProviding> {
        @Trackable<Appearance, any PresenceStateIconProviding>
        public var presenceStateIconProvider: any PresenceStateIconProviding
        
        public init(
            presenceStateIconProvider: any PresenceStateIconProviding,
            titleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            visualProvider: AnyUserAvatarProviding
        ) {
            self._presenceStateIconProvider = Trackable(value: presenceStateIconProvider)
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: nil,
                titleFormatter: titleFormatter,
                subtitleFormatter: EmptyFormatter(),
                visualProvider: visualProvider
            )
        }
        
        public init(
            reference: MessageInputViewController.MentionUsersListViewController.MentionUserCell.Appearance,
            presenceStateIconProvider: (any PresenceStateIconProviding)? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            titleFormatter: AnyUserFormatting? = nil,
            visualProvider: AnyUserAvatarProviding? = nil
        ) {
            self._presenceStateIconProvider = Trackable(reference: reference, referencePath: \.presenceStateIconProvider)
            
            super.init(
                titleLabelAppearance: titleLabelAppearance ?? reference.titleLabelAppearance,
                subtitleLabelAppearance: nil,
                titleFormatter: titleFormatter ?? reference.titleFormatter,
                subtitleFormatter: EmptyFormatter(),
                visualProvider: visualProvider ?? reference.visualProvider
            )

            if let presenceStateIconProvider { self.presenceStateIconProvider = presenceStateIconProvider }
        }
    }
}
