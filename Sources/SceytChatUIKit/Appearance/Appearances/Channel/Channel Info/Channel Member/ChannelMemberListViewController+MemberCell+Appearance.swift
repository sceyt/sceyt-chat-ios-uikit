//
//  ChannelMemberListViewController+MemberCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelMemberListViewController.MemberCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        separatorColor: .border,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        roleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        titleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userNameFormatter),
        subtitleFormatter: AnyUserFormatting(SceytChatUIKit.shared.formatters.userPresenceDateFormatter),
        visualProvider: AnyUserAvatarProviding(SceytChatUIKit.shared.visualProviders.userAvatarProvider)
    )
    
    public class Appearance: CellAppearance<AnyUserFormatting, AnyUserFormatting, AnyUserAvatarProviding> {
        // Trackable properties specific to MemberCell
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var roleLabelAppearance: LabelAppearance
        
        /// Initializes a new instance of `Appearance` with explicit values.
        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance?,
            roleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            subtitleFormatter: AnyUserFormatting,
            visualProvider: AnyUserAvatarProviding
        ) {
            // Initialize Trackable properties with explicit values
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._roleLabelAppearance = Trackable(value: roleLabelAppearance)
            
            // Initialize superclass with provided parameters
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                visualProvider: visualProvider
            )
        }
        
        /// Initializes a new instance of `Appearance` with optional overrides.
        public init(
            reference: ChannelMemberListViewController.MemberCell.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            roleLabelAppearance: LabelAppearance? = nil,
            titleFormatter: AnyUserFormatting? = nil,
            subtitleFormatter: AnyUserFormatting? = nil,
            visualProvider: AnyUserAvatarProviding? = nil
        ) {
            // Initialize Trackable properties with references
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._roleLabelAppearance = Trackable(reference: reference, referencePath: \.roleLabelAppearance)
            
            // Initialize superclass with references or provided overrides
            super.init(
                titleLabelAppearance: titleLabelAppearance ?? reference.titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance ?? reference.subtitleLabelAppearance,
                titleFormatter: titleFormatter ?? reference.titleFormatter,
                subtitleFormatter: subtitleFormatter ?? reference.subtitleFormatter,
                visualProvider: visualProvider ?? reference.visualProvider
            )
            
            // Apply overrides if provided
            if let backgroundColor = backgroundColor {
                self.backgroundColor = backgroundColor
            }
            if let separatorColor = separatorColor {
                self.separatorColor = separatorColor
            }
            if let roleLabelAppearance = roleLabelAppearance {
                self.roleLabelAppearance = roleLabelAppearance
            }
        }
    }
}
