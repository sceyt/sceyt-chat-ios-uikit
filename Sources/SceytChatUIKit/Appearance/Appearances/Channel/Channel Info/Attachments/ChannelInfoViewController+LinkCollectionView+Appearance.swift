//
//  ChannelInfoViewController+LinkCollectionView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.LinkCollectionView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        cellAppearance: SceytChatUIKit.Components.channelInfoLinkCell.appearance,
        separatorAppearance: SceytChatUIKit.Components.channelInfoDateSeparatorView.appearance
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, ChannelInfoViewController.LinkCell.Appearance>
        public var cellAppearance: ChannelInfoViewController.LinkCell.Appearance
        
        @Trackable<Appearance, ChannelInfoViewController.DateSeparatorView.Appearance>
        public var separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance
        
        public init(
            backgroundColor: UIColor,
            cellAppearance: ChannelInfoViewController.LinkCell.Appearance,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._cellAppearance = Trackable(value: cellAppearance)
            self._separatorAppearance = Trackable(value: separatorAppearance)
        }
        
        public init(
            reference: ChannelInfoViewController.LinkCollectionView.Appearance,
            backgroundColor: UIColor? = nil,
            cellAppearance: ChannelInfoViewController.LinkCell.Appearance? = nil,
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
