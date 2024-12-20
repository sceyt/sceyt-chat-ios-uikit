//
//  ReactedUserListViewController+UserReactionCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ReactedUserListViewController.UserReactionCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .clear,
        selectedBackgroundColor: .surface2,
        titleLabelAppearance: .init(
            foregroundColor: .primaryText,
            font: Fonts.bold.withSize(16)
        ),
        subtitleLabelAppearance: .init(
            foregroundColor: .primaryText,
            font: Fonts.bold.withSize(24)
        ),
        titleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
        subtitleFormatter: AnyReactionFormatting(SceytChatUIKit.shared.formatters.reactionFormatter),
        avatarRenderer: AnyUserAvatarRendering(SceytChatUIKit.shared.avatarRenderers.userAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard
    )
    
    public class Appearance: CellAppearance<AnyUserFormatting, AnyReactionFormatting, AnyUserAvatarRendering> {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var selectedBackgroundColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            selectedBackgroundColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance?,
            titleFormatter: AnyUserFormatting,
            subtitleFormatter: AnyReactionFormatting,
            avatarRenderer: AnyUserAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            // Initialize Trackable properties with explicit values
            self._backgroundColor = Trackable(value: backgroundColor)
            self._selectedBackgroundColor = Trackable(value: selectedBackgroundColor)
            
            // Initialize superclass with provided parameters
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
            reference: ReactedUserListViewController.UserReactionCell.Appearance,
            backgroundColor: UIColor? = nil,
            selectedBackgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            titleFormatter: AnyUserFormatting? = nil,
            subtitleFormatter: AnyReactionFormatting? = nil,
            avatarRenderer: AnyUserAvatarRendering? = nil,
            avatarAppearance: AvatarAppearance? = nil
        ) {
            // Initialize Trackable properties with references
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._selectedBackgroundColor = Trackable(reference: reference, referencePath: \.selectedBackgroundColor)
            
            // Initialize superclass with references or provided overrides
            super.init(
                titleLabelAppearance: titleLabelAppearance ?? reference.titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance ?? reference.subtitleLabelAppearance,
                titleFormatter: titleFormatter ?? reference.titleFormatter,
                subtitleFormatter: subtitleFormatter ?? reference.subtitleFormatter,
                avatarRenderer: avatarRenderer ?? reference.avatarRenderer,
                avatarAppearance: avatarAppearance ?? reference.avatarAppearance
            )
            
            // Apply overrides if provided
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let selectedBackgroundColor { self.selectedBackgroundColor = selectedBackgroundColor }
        }
    }
}

