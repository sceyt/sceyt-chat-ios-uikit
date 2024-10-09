//
//  ChannelInfoViewController+VoiceCollectionView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.VoiceCollectionView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        cellAppearance: SceytChatUIKit.Components.channelInfoVoiceCell.appearance,
        separatorAppearance: SceytChatUIKit.Components.channelInfoDateSeparatorView.appearance
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, ChannelInfoViewController.VoiceCell.Appearance>
        public var cellAppearance: ChannelInfoViewController.VoiceCell.Appearance
        
        @Trackable<Appearance, ChannelInfoViewController.DateSeparatorView.Appearance>
        public var separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance
        
        /// Initializes a new instance of `Appearance` with explicit values.
        public init(
            backgroundColor: UIColor,
            cellAppearance: ChannelInfoViewController.VoiceCell.Appearance,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._cellAppearance = Trackable(value: cellAppearance)
            self._separatorAppearance = Trackable(value: separatorAppearance)
        }
        
        /// Initializes a new instance of `Appearance` with optional overrides.
        public init(
            reference: ChannelInfoViewController.VoiceCollectionView.Appearance,
            backgroundColor: UIColor? = nil,
            cellAppearance: ChannelInfoViewController.VoiceCell.Appearance? = nil,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._cellAppearance = Trackable(reference: reference, referencePath: \.cellAppearance)
            self._separatorAppearance = Trackable(reference: reference, referencePath: \.separatorAppearance)
            
            if let backgroundColor = backgroundColor {
                self.backgroundColor = backgroundColor
            }
            if let cellAppearance = cellAppearance {
                self.cellAppearance = cellAppearance
            }
            if let separatorAppearance = separatorAppearance {
                self.separatorAppearance = separatorAppearance
            }
        }
    }
}
