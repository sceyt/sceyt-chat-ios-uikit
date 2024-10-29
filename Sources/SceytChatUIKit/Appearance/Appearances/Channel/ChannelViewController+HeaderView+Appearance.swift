//
//  ChannelViewController+HeaderView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController.HeaderView: AppearanceProviding {
    public static var appearance = Appearance(
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(19)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(13)
        ),
        titleFormatter: SceytChatUIKit.shared.formatters.channelNameFormatter,
        subtitleFormatter: SceytChatUIKit.shared.formatters.channelSubtitleFormatter,
        typingUserNameFormatter: SceytChatUIKit.shared.formatters.typingUserNameFormatter,
        avatarRenderer: SceytChatUIKit.shared.avatarRenderers.channelAvatarRenderer,
        avatarAppearance: AvatarAppearance.standard
    )
    
    public struct Appearance {
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var subtitleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, any ChannelFormatting>
        public var titleFormatter: any ChannelFormatting
        
        @Trackable<Appearance, any ChannelFormatting>
        public var subtitleFormatter: any ChannelFormatting
        
        @Trackable<Appearance, any UserFormatting>
        public var typingUserNameFormatter: any UserFormatting
        
        @Trackable<Appearance, ChannelAvatarRendering>
        public var avatarRenderer: any ChannelAvatarRendering
        
        @Trackable<Appearance, AvatarAppearance>
        public var avatarAppearance: AvatarAppearance

        public init(
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            titleFormatter: any ChannelFormatting,
            subtitleFormatter: any ChannelFormatting,
            typingUserNameFormatter: any UserFormatting,
            avatarRenderer: any ChannelAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
            self._titleFormatter = Trackable(value: titleFormatter)
            self._subtitleFormatter = Trackable(value: subtitleFormatter)
            self._typingUserNameFormatter = Trackable(value: typingUserNameFormatter)
            self._avatarRenderer = Trackable(value: avatarRenderer)
            self._avatarAppearance = Trackable(value: avatarAppearance)
        }
        
        public init(
            reference: ChannelViewController.HeaderView.Appearance,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            titleFormatter: (any ChannelFormatting)? = nil,
            subtitleFormatter: (any ChannelFormatting)? = nil,
            typingUserNameFormatter: (any UserFormatting)? = nil,
            avatarRenderer: (any ChannelAvatarRendering)? = nil,
            avatarAppearance: AvatarAppearance? = nil
        ) {
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(reference: reference, referencePath: \.subtitleLabelAppearance)
            self._titleFormatter = Trackable(reference: reference, referencePath: \.titleFormatter)
            self._subtitleFormatter = Trackable(reference: reference, referencePath: \.subtitleFormatter)
            self._typingUserNameFormatter = Trackable(reference: reference, referencePath: \.typingUserNameFormatter)
            self._avatarRenderer = Trackable(reference: reference, referencePath: \.avatarRenderer)
            self._avatarAppearance = Trackable(reference: reference, referencePath: \.avatarAppearance)

            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let subtitleLabelAppearance { self.subtitleLabelAppearance = subtitleLabelAppearance }
            if let titleFormatter { self.titleFormatter = titleFormatter }
            if let subtitleFormatter { self.subtitleFormatter = subtitleFormatter }
            if let typingUserNameFormatter { self.typingUserNameFormatter = typingUserNameFormatter }
            if let avatarRenderer { self.avatarRenderer = avatarRenderer }
            if let avatarAppearance { self.avatarAppearance = avatarAppearance }
        }
    }
}
