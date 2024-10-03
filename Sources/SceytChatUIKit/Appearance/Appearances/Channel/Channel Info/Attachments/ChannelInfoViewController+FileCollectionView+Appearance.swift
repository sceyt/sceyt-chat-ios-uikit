//
//  ChannelInfoViewController+FileCollectionView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.FileCollectionView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .background
        public var cellAppearance: ChannelInfoViewController.FileCell.Appearance = SceytChatUIKit.Components.channelInfoFileCell.appearance
        public var separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance = SceytChatUIKit.Components.channelInfoDateSeparatorView.appearance
        
        public init(
            backgroundColor: UIColor = .background,
            cellAppearance: ChannelInfoViewController.FileCell.Appearance = SceytChatUIKit.Components.channelInfoFileCell.appearance,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance = SceytChatUIKit.Components.channelInfoDateSeparatorView.appearance
        ) {
            self.backgroundColor = backgroundColor
            self.cellAppearance = cellAppearance
            self.separatorAppearance = separatorAppearance
        }
    }
}
