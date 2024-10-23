//
//  ChannelMemberListViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelMemberListViewController: AppearanceProviding {
    public static var appearance = Appearance(
        navigationBarAppearance: {
            $0.standardAppearance?.backgroundColor = .surface1
            return $0
        }(NavigationBarAppearance.appearance),
        backgroundColor: .background,
        cellAppearance: SceytChatUIKit.Components.channelMemberCell.appearance,
        addCellAppearance: SceytChatUIKit.Components.channelAddMemberCell.appearance
    )
    
    public struct Appearance {
        @Trackable<Appearance, NavigationBarAppearance.Appearance>
        public var navigationBarAppearance: NavigationBarAppearance.Appearance
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, ChannelMemberListViewController.MemberCell.Appearance>
        public var cellAppearance: ChannelMemberListViewController.MemberCell.Appearance
        
        @Trackable<Appearance, ChannelMemberListViewController.AddMemberCell.Appearance>
        public var addCellAppearance: ChannelMemberListViewController.AddMemberCell.Appearance
        
        /// Initializes a new instance of `Appearance` with explicit values.
        public init(
            navigationBarAppearance: NavigationBarAppearance.Appearance,
            backgroundColor: UIColor,
            cellAppearance: ChannelMemberListViewController.MemberCell.Appearance,
            addCellAppearance: ChannelMemberListViewController.AddMemberCell.Appearance
        ) {
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._backgroundColor = Trackable(value: backgroundColor)
            self._cellAppearance = Trackable(value: cellAppearance)
            self._addCellAppearance = Trackable(value: addCellAppearance)
        }
        
        /// Initializes a new instance of `Appearance` with optional overrides.
        public init(
            reference: ChannelMemberListViewController.Appearance,
            navigationBarAppearance: NavigationBarAppearance.Appearance? = nil,
            backgroundColor: UIColor? = nil,
            cellAppearance: ChannelMemberListViewController.MemberCell.Appearance? = nil,
            addCellAppearance: ChannelMemberListViewController.AddMemberCell.Appearance? = nil
        ) {
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            self._addCellAppearance = Trackable(reference: reference, referencePath: \.addCellAppearance)
            
            if let navigationBarAppearance = navigationBarAppearance {
                self.navigationBarAppearance = navigationBarAppearance
            }
            if let backgroundColor = backgroundColor {
                self.backgroundColor = backgroundColor
            }
            if let cellAppearance = cellAppearance {
                self.cellAppearance = cellAppearance
            }
            if let addCellAppearance = addCellAppearance {
                self.addCellAppearance = addCellAppearance
            }
        }
    }
}
