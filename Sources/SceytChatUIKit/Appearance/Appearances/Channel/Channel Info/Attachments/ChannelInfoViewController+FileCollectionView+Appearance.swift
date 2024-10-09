//
//  ChannelInfoViewController+FileCollectionView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.FileCollectionView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        cellAppearance: SceytChatUIKit.Components.channelInfoFileCell.appearance,
        separatorAppearance: SceytChatUIKit.Components.channelInfoDateSeparatorView.appearance
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, ChannelInfoViewController.FileCell.Appearance>
        public var cellAppearance: ChannelInfoViewController.FileCell.Appearance
        
        @Trackable<Appearance, ChannelInfoViewController.DateSeparatorView.Appearance>
        public var separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance
        
        public init(
            backgroundColor: UIColor,
            cellAppearance: ChannelInfoViewController.FileCell.Appearance,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._cellAppearance = Trackable(value: cellAppearance)
            self._separatorAppearance = Trackable(value: separatorAppearance)
        }
        
        public init(
            reference: ChannelInfoViewController.FileCollectionView.Appearance,
            backgroundColor: UIColor? = nil,
            cellAppearance: ChannelInfoViewController.FileCell.Appearance? = nil,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            self._separatorAppearance = Trackable(reference: reference, referencePath: \.separatorAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let cellAppearance { self.cellAppearance = cellAppearance }
            if let separatorAppearance { self.separatorAppearance = separatorAppearance }
        }
    }
}
