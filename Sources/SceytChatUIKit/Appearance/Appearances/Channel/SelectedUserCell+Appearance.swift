//
//  SelectedUserCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 29.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SelectedUserCell: AppearanceProviding {
    
    public static var appearance = Appearance(
        backgroundColor: .clear,
        labelAppearance: .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(13)
        ),
        titleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userShortNameFormatter),
        removeIcon: .closeCircle,
        avatarRenderer: AnyUserAvatarRendering(SceytChatUIKit.shared.avatarRenderers.userAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard
    )
    
    public class Appearance: SelectedCellAppearance<AnyUserFormatting, AnyUserAvatarRendering> {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            removeIcon: UIImage,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            
            super.init(
                labelAppearance: labelAppearance,
                titleFormatter: titleFormatter,
                removeIcon: removeIcon,
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance
            )
        }
        
        public init(
            reference: SelectedUserCell.Appearance,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            removeIcon: UIImage,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            
            super.init(
                labelAppearance: labelAppearance,
                titleFormatter: titleFormatter,
                removeIcon: removeIcon,
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance
            )
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
        }
    }
}
