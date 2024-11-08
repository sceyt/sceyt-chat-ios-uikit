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
        channelAvatarRenderer: SceytChatUIKit.shared.avatarRenderers.channelAvatarRenderer,
        avatarAppearance: AvatarAppearance.standard,
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
        
        @Trackable<Appearance, any ChannelAvatarRendering>
        public var channelAvatarRenderer: any ChannelAvatarRendering
        
        @Trackable<Appearance, AvatarAppearance>
        public var avatarAppearance: AvatarAppearance

        @Trackable<Appearance, any ChannelFormatting>
        public var channelNameFormatter: any ChannelFormatting
        
        @Trackable<Appearance, any ChannelFormatting>
        public var channelSubtitleFormatter: any ChannelFormatting
        
        public init(
            backgroundColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            channelAvatarRenderer: any ChannelAvatarRendering,
            avatarAppearance: AvatarAppearance,
            channelNameFormatter: any ChannelFormatting,
            channelSubtitleFormatter: any ChannelFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
            self._channelAvatarRenderer = Trackable(value: channelAvatarRenderer)
            self._avatarAppearance = Trackable(value: avatarAppearance)
            self._channelNameFormatter = Trackable(value: channelNameFormatter)
            self._channelSubtitleFormatter = Trackable(value: channelSubtitleFormatter)
        }
        
        public init(
            reference: ChannelInfoViewController.DetailsCell.Appearance,
            backgroundColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            channelAvatarRenderer: (any ChannelAvatarRendering)? = nil,
            avatarAppearance: AvatarAppearance? = nil,
            channelNameFormatter: (any ChannelFormatting)? = nil,
            channelSubtitleFormatter: (any ChannelFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(reference: reference, referencePath: \.subtitleLabelAppearance)
            self._channelAvatarRenderer = Trackable(reference: reference, referencePath: \.channelAvatarRenderer)
            self._avatarAppearance = Trackable(reference: reference, referencePath: \.avatarAppearance)
            self._channelNameFormatter = Trackable(reference: reference, referencePath: \.channelNameFormatter)
            self._channelSubtitleFormatter = Trackable(reference: reference, referencePath: \.channelSubtitleFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let subtitleLabelAppearance { self.subtitleLabelAppearance = subtitleLabelAppearance }
            if let channelAvatarRenderer { self.channelAvatarRenderer = channelAvatarRenderer }
            if let avatarAppearance { self.avatarAppearance = avatarAppearance }
            if let channelNameFormatter { self.channelNameFormatter = channelNameFormatter }
            if let channelSubtitleFormatter { self.channelSubtitleFormatter = channelSubtitleFormatter }
        }
    }
}
