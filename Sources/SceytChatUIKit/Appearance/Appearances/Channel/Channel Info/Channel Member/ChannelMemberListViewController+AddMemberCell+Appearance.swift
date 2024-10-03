//
//  ChannelMemberListViewController+AddMemberCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelMemberListViewController.AddMemberCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .background
        public var addIcon: UIImage = .addMember
        public var titleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        )
        public var separatorColor: UIColor = UIColor.border
        
        public init(
            backgroundColor: UIColor = .background,
            addIcon: UIImage = .addMember,
            titleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.regular.withSize(16)
            ),
            separatorColor: UIColor = UIColor.border
        ) {
            self.backgroundColor = backgroundColor
            self.addIcon = addIcon
            self.titleLabelAppearance = titleLabelAppearance
            self.separatorColor = separatorColor
        }
    }
}
