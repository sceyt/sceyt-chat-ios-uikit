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
        visualProvider: AnyUserAvatarProviding(SceytChatUIKit.shared.visualProviders.userAvatarProvider)
    )
    
    public class Appearance: CellAppearance<AnyUserFormatting, AnyDateFormatting, AnyUserAvatarProviding> {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            subtitleFormatter: AnyDateFormatting,
            visualProvider: AnyUserAvatarProviding
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                visualProvider: visualProvider
            )
        }
        
        public init(
            reference: MessageInfoViewController.MarkerCell.Appearance,
            backgroundColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            titleFormatter: AnyUserFormatting,
            subtitleFormatter: AnyDateFormatting,
            visualProvider: AnyUserAvatarProviding
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                visualProvider: visualProvider
            )
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
        }
    }
}
