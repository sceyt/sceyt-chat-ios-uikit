//
//  ChannelInfoViewController+DetailsCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.DetailsCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .backgroundSections,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.bold.withSize(20)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(16)
        ),
        channelDefaultAvatarProvider: SceytChatUIKit.shared.visualProviders.channelDefaultAvatarProvider,
        channelNameFormatter: SceytChatUIKit.shared.formatters.channelNameFormatter,
        channelSubtitleFormatter: SceytChatUIKit.shared.formatters.channelSubtitleFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var subtitleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, any ChannelAvatarProviding>
        public var channelDefaultAvatarProvider: any ChannelAvatarProviding
        
        @Trackable<Appearance, any ChannelFormatting>
        public var channelNameFormatter: any ChannelFormatting
        
        @Trackable<Appearance, any ChannelFormatting>
        public var channelSubtitleFormatter: any ChannelFormatting
        
        public init(
            backgroundColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            channelDefaultAvatarProvider: any ChannelAvatarProviding,
            channelNameFormatter: any ChannelFormatting,
            channelSubtitleFormatter: any ChannelFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
            self._channelDefaultAvatarProvider = Trackable(value: channelDefaultAvatarProvider)
            self._channelNameFormatter = Trackable(value: channelNameFormatter)
            self._channelSubtitleFormatter = Trackable(value: channelSubtitleFormatter)
        }
        
        public init(
            reference: ChannelInfoViewController.DetailsCell.Appearance,
            backgroundColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            channelDefaultAvatarProvider: (any ChannelAvatarProviding)? = nil,
            channelNameFormatter: (any ChannelFormatting)? = nil,
            channelSubtitleFormatter: (any ChannelFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(reference: reference, referencePath: \.subtitleLabelAppearance)
            self._channelDefaultAvatarProvider = Trackable(reference: reference, referencePath: \.channelDefaultAvatarProvider)
            self._channelNameFormatter = Trackable(reference: reference, referencePath: \.channelNameFormatter)
            self._channelSubtitleFormatter = Trackable(reference: reference, referencePath: \.channelSubtitleFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let subtitleLabelAppearance { self.subtitleLabelAppearance = subtitleLabelAppearance }
            if let channelDefaultAvatarProvider { self.channelDefaultAvatarProvider = channelDefaultAvatarProvider }
            if let channelNameFormatter { self.channelNameFormatter = channelNameFormatter }
            if let channelSubtitleFormatter { self.channelSubtitleFormatter = channelSubtitleFormatter }
        }
    }
}
