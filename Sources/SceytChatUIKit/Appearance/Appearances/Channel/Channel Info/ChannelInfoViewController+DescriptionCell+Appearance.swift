//
//  ChannelInfoViewController+DescriptionCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.DescriptionCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .backgroundSections,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        descriptionLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        titleText: L10n.Channel.Info.about
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var descriptionLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, String>
        public var titleText: String
        
        public init(
            backgroundColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            descriptionLabelAppearance: LabelAppearance,
            titleText: String
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._descriptionLabelAppearance = Trackable(value: descriptionLabelAppearance)
            self._titleText = Trackable(value: titleText)
        }
        
        public init(
            reference: ChannelInfoViewController.DescriptionCell.Appearance,
            backgroundColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            descriptionLabelAppearance: LabelAppearance? = nil,
            titleText: String? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._descriptionLabelAppearance = Trackable(reference: reference, referencePath: \.descriptionLabelAppearance)
            self._titleText = Trackable(reference: reference, referencePath: \.titleText)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let descriptionLabelAppearance { self.descriptionLabelAppearance = descriptionLabelAppearance }
            if let titleText { self.titleText = titleText }
        }
    }
}
