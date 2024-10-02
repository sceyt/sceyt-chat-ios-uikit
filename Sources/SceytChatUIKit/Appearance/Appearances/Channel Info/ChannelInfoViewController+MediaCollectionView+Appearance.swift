//
//  ChannelInfoViewController+MediaCollectionView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.MediaCollectionView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .background
        public lazy var videoAttachmentCellAppearance: ChannelInfoViewController.VideoAttachmentCell.Appearance = Components.channelInfoVideoAttachmentCell.appearance
        public lazy var separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance = Components.channelInfoDateSeparatorView.appearance
        
        public init(
            backgroundColor: UIColor = .background,
            videoAttachmentCellAppearance: ChannelInfoViewController.VideoAttachmentCell.Appearance = SceytChatUIKit.Components.channelInfoVideoAttachmentCell.appearance,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance = SceytChatUIKit.Components.channelInfoDateSeparatorView.appearance
        ) {
            self.backgroundColor = backgroundColor
            self.videoAttachmentCellAppearance = videoAttachmentCellAppearance
            self.separatorAppearance = separatorAppearance
        }
    }
}
