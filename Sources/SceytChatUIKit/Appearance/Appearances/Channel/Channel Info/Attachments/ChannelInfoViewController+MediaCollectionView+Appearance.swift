//
//  ChannelInfoViewController+MediaCollectionView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.MediaCollectionView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        videoAttachmentCellAppearance: SceytChatUIKit.Components.channelInfoVideoAttachmentCell.appearance,
        separatorAppearance: SceytChatUIKit.Components.channelInfoDateSeparatorView.appearance
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, ChannelInfoViewController.VideoAttachmentCell.Appearance>
        public var videoAttachmentCellAppearance: ChannelInfoViewController.VideoAttachmentCell.Appearance
        
        @Trackable<Appearance, ChannelInfoViewController.DateSeparatorView.Appearance>
        public var separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance
        
        /// Initializer with explicit values
        public init(
            backgroundColor: UIColor,
            videoAttachmentCellAppearance: ChannelInfoViewController.VideoAttachmentCell.Appearance,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._videoAttachmentCellAppearance = Trackable(value: videoAttachmentCellAppearance)
            self._separatorAppearance = Trackable(value: separatorAppearance)
        }
        
        /// Initializer with optional overrides
        public init(
            reference: ChannelInfoViewController.MediaCollectionView.Appearance,
            backgroundColor: UIColor? = nil,
            videoAttachmentCellAppearance: ChannelInfoViewController.VideoAttachmentCell.Appearance? = nil,
            separatorAppearance: ChannelInfoViewController.DateSeparatorView.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._videoAttachmentCellAppearance = Trackable(reference: reference, referencePath: \.videoAttachmentCellAppearance)
            self._separatorAppearance = Trackable(reference: reference, referencePath: \.separatorAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let videoAttachmentCellAppearance { self.videoAttachmentCellAppearance = videoAttachmentCellAppearance }
            if let separatorAppearance { self.separatorAppearance = separatorAppearance }
        }
    }
}
