//
//  MessageInputViewController+MentionUsersListViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24.
//

import UIKit

extension MessageInputViewController.MentionUsersListViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor? = .backgroundSections
        public var separatorColor: UIColor? = .border
        public var shadowColor: UIColor? = .primaryText.withAlphaComponent(0.16)
        public var cellAppearance: MentionUserCell.Appearance = MentionUserCell.appearance
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor? = .backgroundSections,
            separatorColor: UIColor? = .border,
            shadowColor: UIColor? = .primaryText.withAlphaComponent(0.16),
            cellAppearance: MentionUserCell.Appearance = MentionUserCell.appearance
        ) {
            self.backgroundColor = backgroundColor
            self.separatorColor = separatorColor
            self.shadowColor = shadowColor
            self.cellAppearance = cellAppearance
        }
    }
}
