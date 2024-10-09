//
//  MessageInputViewController+MentionUsersListViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24.
//

import UIKit

extension MessageInputViewController.MentionUsersListViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .backgroundSections,
        separatorColor: .border,
        shadowColor: .primaryText.withAlphaComponent(0.16),
        cellAppearance: MentionUserCell.appearance
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor?>
        public var backgroundColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var separatorColor: UIColor?
        
        @Trackable<Appearance, UIColor?>
        public var shadowColor: UIColor?
        
        @Trackable<Appearance, MentionUserCell.Appearance>
        public var cellAppearance: MentionUserCell.Appearance
        
        public init(
            backgroundColor: UIColor?,
            separatorColor: UIColor?,
            shadowColor: UIColor?,
            cellAppearance: MentionUserCell.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._shadowColor = Trackable(value: shadowColor)
            self._cellAppearance = Trackable(value: cellAppearance)
        }
        
        public init(
            reference: MessageInputViewController.MentionUsersListViewController.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            shadowColor: UIColor? = nil,
            cellAppearance: MentionUserCell.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._shadowColor = Trackable(reference: reference, referencePath: \.shadowColor)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let shadowColor { self.shadowColor = shadowColor }
            if let cellAppearance { self.cellAppearance = cellAppearance }
        }
    }
}
