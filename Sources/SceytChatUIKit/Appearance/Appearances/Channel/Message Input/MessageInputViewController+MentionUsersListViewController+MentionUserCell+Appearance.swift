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
        avatarRenderer: AnyUserAvatarRendering(SceytChatUIKit.shared.avatarRenderers.userAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard
    )
    
    public class Appearance: CellAppearance<AnyUserFormatting, EmptyFormatter, AnyUserAvatarRendering> {
        
        @Trackable<Appearance, any PresenceStateIconProviding>
        public var presenceStateIconProvider: any PresenceStateIconProviding
        
        public init(
            presenceStateIconProvider: any PresenceStateIconProviding,
            titleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            self._presenceStateIconProvider = Trackable(value: presenceStateIconProvider)
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: nil,
                titleFormatter: titleFormatter,
                subtitleFormatter: EmptyFormatter(),
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance
            )
        }
        
        public init(
            reference: MessageInputViewController.MentionUsersListViewController.MentionUserCell.Appearance,
            presenceStateIconProvider: (any PresenceStateIconProviding)? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            titleFormatter: AnyUserFormatting? = nil,
            avatarRenderer: AnyUserAvatarRendering? = nil,
            avatarAppearance: AvatarAppearance? = nil
        ) {
            self._presenceStateIconProvider = Trackable(reference: reference, referencePath: \.presenceStateIconProvider)
            
            super.init(
                titleLabelAppearance: titleLabelAppearance ?? reference.titleLabelAppearance,
                subtitleLabelAppearance: nil,
                titleFormatter: titleFormatter ?? reference.titleFormatter,
                subtitleFormatter: EmptyFormatter(),
                avatarRenderer: avatarRenderer ?? reference.avatarRenderer,
                avatarAppearance: avatarAppearance ?? reference.avatarAppearance
            )

            if let presenceStateIconProvider { self.presenceStateIconProvider = presenceStateIconProvider }
        }
    }
}
