//
//  ReactionsInfoViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ReactionsInfoViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        separatorColor: .border,
        headerCellAppearance: Components.reactionsInfoHeaderCell.appearance,
        reactedUserCellAppearance: Components.reactedUserReactionCell.appearance
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        @Trackable<Appearance, ReactionsInfoViewController.HeaderCell.Appearance>
        public var headerCellAppearance: ReactionsInfoViewController.HeaderCell.Appearance
        
        @Trackable<Appearance, ReactedUserListViewController.UserReactionCell.Appearance>
        public var reactedUserCellAppearance: ReactedUserListViewController.UserReactionCell.Appearance
        
        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            headerCellAppearance: ReactionsInfoViewController.HeaderCell.Appearance,
            reactedUserCellAppearance: ReactedUserListViewController.UserReactionCell.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._headerCellAppearance = Trackable(value: headerCellAppearance)
            self._reactedUserCellAppearance = Trackable(value: reactedUserCellAppearance)
        }
        
        public init(
            reference: ReactionsInfoViewController.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            headerCellAppearance: ReactionsInfoViewController.HeaderCell.Appearance? = nil,
            reactedUserCellAppearance: ReactedUserListViewController.UserReactionCell.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._headerCellAppearance = Trackable(reference: reference, referencePath: \.headerCellAppearance)
            self._reactedUserCellAppearance = Trackable(reference: reference, referencePath: \.reactedUserCellAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let headerCellAppearance { self.headerCellAppearance = headerCellAppearance }
            if let reactedUserCellAppearance { self.reactedUserCellAppearance = reactedUserCellAppearance }
        }
    }
}
