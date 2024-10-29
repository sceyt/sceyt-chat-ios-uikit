//
//  SelectedChannelCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 29.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SelectedChannelCell: AppearanceProviding {
    
    public static var appearance = Appearance(
        backgroundColor: .clear,
        labelAppearance: .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(13)
        ),
        titleFormatter: AnyChannelFormatting(SceytChatUIKit.shared.formatters.channelNameFormatter),
        removeIcon: .closeCircle,
        avatarRenderer: AnyChannelAvatarRendering(SceytChatUIKit.shared.avatarRenderers.channelAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard
    )
    
    public class Appearance: SelectedCellAppearance<AnyChannelFormatting, AnyChannelAvatarRendering> {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            labelAppearance: LabelAppearance,
            titleFormatter: AnyChannelFormatting,
            removeIcon: UIImage,
            avatarRenderer: AnyChannelAvatarRendering,
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
            reference: SelectedChannelCell.Appearance,
            backgroundColor: UIColor? = nil,
            labelAppearance: LabelAppearance,
            titleFormatter: AnyChannelFormatting,
            removeIcon: UIImage,
            avatarRenderer: AnyChannelAvatarRendering,
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
