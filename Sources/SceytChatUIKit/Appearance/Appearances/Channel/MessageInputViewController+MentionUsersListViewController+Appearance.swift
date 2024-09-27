//
//  MessageInputViewController+MentionUsersListViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24.
//

import UIKit

extension MessageInputViewController.MentionUsersListViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor? = .backgroundSections
        public lazy var separatorColor: UIColor? = .border
        public lazy var shadowColor: UIColor? = .primaryText.withAlphaComponent(0.16)
        public lazy var cellAppearance: MentionUserCell.Appearance = MentionUserCell.appearance
        
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
