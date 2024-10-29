//
//  SelectableUserCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SelectableUserCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .clear,
        separatorColor: .border,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        titleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
        subtitleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userPresenceDateFormatter),
        avatarRenderer: AnyUserAvatarRendering(SceytChatUIKit.shared.avatarRenderers.userAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard,
        checkBoxAppearance: CheckBoxView.appearance
    )
    
    public class Appearance: SelectableCellAppearance<AnyUserFormatting, AnyUserFormatting, AnyUserAvatarRendering> {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            subtitleFormatter: AnyUserFormatting,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance,
            checkBoxAppearance: CheckBoxView.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance,
                checkBoxAppearance: checkBoxAppearance
            )
        }
        
        public init(
            reference: SelectableUserCell.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            subtitleFormatter: AnyUserFormatting,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance,
            checkBoxAppearance: CheckBoxView.Appearance
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance,
                checkBoxAppearance: checkBoxAppearance
            )
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
        }
    }
}
