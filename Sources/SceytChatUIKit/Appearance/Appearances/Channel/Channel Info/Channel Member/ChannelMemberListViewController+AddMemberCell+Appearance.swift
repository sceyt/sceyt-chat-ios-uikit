//
//  ChannelMemberListViewController+AddMemberCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelMemberListViewController.AddMemberCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        addIcon: .addMember,
        titleLabelAppearance: .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        separatorColor: UIColor.border
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        @Trackable<Appearance, UIImage>
        public var addIcon: UIImage
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        public init(
            backgroundColor: UIColor,
            addIcon: UIImage,
            titleLabelAppearance: LabelAppearance,
            separatorColor: UIColor
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._addIcon = Trackable(value: addIcon)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._separatorColor = Trackable(value: separatorColor)
        }
        
        public init(
            reference: ChannelMemberListViewController.AddMemberCell.Appearance,
            backgroundColor: UIColor? = nil,
            addIcon: UIImage? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            separatorColor: UIColor? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._addIcon = Trackable(reference: reference, referencePath: \.addIcon)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            
            if let backgroundColor {
                self.backgroundColor = backgroundColor
            }
            if let addIcon {
                self.addIcon = addIcon
            }
            if let titleLabelAppearance {
                self.titleLabelAppearance = titleLabelAppearance
            }
            if let separatorColor {
                self.separatorColor = separatorColor
            }
        }
    }
}
