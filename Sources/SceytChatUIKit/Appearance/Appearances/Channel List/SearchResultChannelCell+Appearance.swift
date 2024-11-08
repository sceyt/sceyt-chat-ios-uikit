//
//  SearchResultChannelCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension SearchResultChannelCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .clear,
        separatorColor: .border,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        titleFormatter: AnyChannelFormatting(SceytChatUIKit.shared.formatters.channelNameFormatter),
        subtitleFormatter: AnyChannelFormatting(SceytChatUIKit.shared.formatters.channelSubtitleFormatter),
        avatarRenderer: AnyChannelAvatarRendering(SceytChatUIKit.shared.avatarRenderers.channelAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard
    )
    
    public class Appearance: CellAppearance<AnyChannelFormatting, AnyChannelFormatting, AnyChannelAvatarRendering> {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            titleFormatter: AnyChannelFormatting,
            subtitleFormatter: AnyChannelFormatting,
            avatarRenderer: AnyChannelAvatarRendering,
            avatarAppearance: AvatarAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: subtitleFormatter,
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance
            )
        }
        
        // Convenience initializer with optional parameters
        public init(
            reference: SearchResultChannelCell.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            titleFormatter: AnyChannelFormatting? = nil,
            subtitleFormatter: AnyChannelFormatting? = nil,
            avatarRenderer: AnyChannelAvatarRendering? = nil,
            avatarAppearance: AvatarAppearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            super.init(
                titleLabelAppearance: titleLabelAppearance ?? reference.titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance ?? reference.subtitleLabelAppearance,
                titleFormatter: titleFormatter ?? reference.titleFormatter,
                subtitleFormatter: subtitleFormatter ?? reference.subtitleFormatter,
                avatarRenderer: avatarRenderer ?? reference.avatarRenderer,
                avatarAppearance: avatarAppearance ?? reference.avatarAppearance
            )
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
        }
    }
}
