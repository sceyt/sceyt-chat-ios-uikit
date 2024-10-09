//
//  ChannelInfoViewController+OptionCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.OptionCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .backgroundSections,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        descriptionLabelAppearance: nil,
        switchTintColor: nil,
        accessoryImage: nil
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance?>
        public var descriptionLabelAppearance: LabelAppearance?
        
        @Trackable<Appearance, UIColor?>
        public var switchTintColor: UIColor?
        
        @Trackable<Appearance, UIImage?>
        public var accessoryImage: UIImage?
        
        public init(
            backgroundColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            descriptionLabelAppearance: LabelAppearance?,
            switchTintColor: UIColor?,
            accessoryImage: UIImage?
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._descriptionLabelAppearance = Trackable(value: descriptionLabelAppearance)
            self._switchTintColor = Trackable(value: switchTintColor)
            self._accessoryImage = Trackable(value: accessoryImage)
        }
        
        public init(
            reference: ChannelInfoViewController.OptionCell.Appearance,
            backgroundColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            descriptionLabelAppearance: LabelAppearance? = nil,
            switchTintColor: UIColor? = nil,
            accessoryImage: UIImage? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._descriptionLabelAppearance = Trackable(reference: reference, referencePath: \.descriptionLabelAppearance)
            self._switchTintColor = Trackable(reference: reference, referencePath: \.switchTintColor)
            self._accessoryImage = Trackable(reference: reference, referencePath: \.accessoryImage)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let descriptionLabelAppearance { self.descriptionLabelAppearance = descriptionLabelAppearance }
            if let switchTintColor { self.switchTintColor = switchTintColor }
            if let accessoryImage { self.accessoryImage = accessoryImage }
        }
    }
}
