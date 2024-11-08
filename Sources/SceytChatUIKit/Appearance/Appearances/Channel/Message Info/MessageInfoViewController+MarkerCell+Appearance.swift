//
//  MessageInfoViewController+MarkerCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInfoViewController.MarkerCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .backgroundSections,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        titleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
        subtitleFormatter: AnyDateFormatting(SceytChatUIKit.shared.formatters.messageInfoMarkerDateFormatter),
        avatarRenderer: AnyUserAvatarRendering(SceytChatUIKit.shared.avatarRenderers.userAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard
    )
    
    public class Appearance: CellAppearance<AnyUserFormatting, AnyDateFormatting, AnyUserAvatarRendering> {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            subtitleFormatter: AnyDateFormatting,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance
            )
        }
        
        public init(
            reference: MessageInfoViewController.MarkerCell.Appearance,
            backgroundColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            subtitleFormatter: AnyDateFormatting,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance
            )
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
        }
    }
}
