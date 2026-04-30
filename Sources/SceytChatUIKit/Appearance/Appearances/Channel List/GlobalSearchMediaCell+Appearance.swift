//
//  GlobalSearchMediaCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension GlobalSearchMediaCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .clear,
        separatorColor: .border,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(15)
        ),
        dateLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(14)
        ),
        senderNameLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(15)
        ),
        highlightedBodyLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(15)
        ),
        thumbnailPlaceholderColor: .secondaryText.withAlphaComponent(0.2),
        titleFormatter: AnyChannelFormatting(SceytChatUIKit.shared.formatters.channelNameFormatter),
        avatarRenderer: AnyChannelAvatarRendering(SceytChatUIKit.shared.avatarRenderers.channelAvatarRenderer),
        avatarAppearance: AvatarAppearance.standard,
        channelDateFormatter: SceytChatUIKit.shared.formatters.channelDateFormatter
    )

    public class Appearance: CellAppearance<AnyChannelFormatting, AnyChannelFormatting, AnyChannelAvatarRendering> {

        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor

        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor

        @Trackable<Appearance, LabelAppearance>
        public var dateLabelAppearance: LabelAppearance

        @Trackable<Appearance, LabelAppearance>
        public var senderNameLabelAppearance: LabelAppearance

        @Trackable<Appearance, LabelAppearance>
        public var highlightedBodyLabelAppearance: LabelAppearance

        @Trackable<Appearance, UIColor>
        public var thumbnailPlaceholderColor: UIColor

        @Trackable<Appearance, any DateFormatting>
        public var channelDateFormatter: any DateFormatting

        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            dateLabelAppearance: LabelAppearance,
            senderNameLabelAppearance: LabelAppearance,
            highlightedBodyLabelAppearance: LabelAppearance,
            thumbnailPlaceholderColor: UIColor,
            titleFormatter: AnyChannelFormatting,
            avatarRenderer: AnyChannelAvatarRendering,
            avatarAppearance: AvatarAppearance,
            channelDateFormatter: any DateFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._dateLabelAppearance = Trackable(value: dateLabelAppearance)
            self._senderNameLabelAppearance = Trackable(value: senderNameLabelAppearance)
            self._highlightedBodyLabelAppearance = Trackable(value: highlightedBodyLabelAppearance)
            self._thumbnailPlaceholderColor = Trackable(value: thumbnailPlaceholderColor)
            self._channelDateFormatter = Trackable(value: channelDateFormatter)
            super.init(
                titleLabelAppearance: titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance,
                titleFormatter: titleFormatter,
                subtitleFormatter: titleFormatter,
                avatarRenderer: avatarRenderer,
                avatarAppearance: avatarAppearance
            )
        }

        public init(
            reference: GlobalSearchMediaCell.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            dateLabelAppearance: LabelAppearance? = nil,
            senderNameLabelAppearance: LabelAppearance? = nil,
            highlightedBodyLabelAppearance: LabelAppearance? = nil,
            thumbnailPlaceholderColor: UIColor? = nil,
            titleFormatter: AnyChannelFormatting? = nil,
            avatarRenderer: AnyChannelAvatarRendering? = nil,
            avatarAppearance: AvatarAppearance? = nil,
            channelDateFormatter: (any DateFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._dateLabelAppearance = Trackable(reference: reference, referencePath: \.dateLabelAppearance)
            self._senderNameLabelAppearance = Trackable(reference: reference, referencePath: \.senderNameLabelAppearance)
            self._highlightedBodyLabelAppearance = Trackable(reference: reference, referencePath: \.highlightedBodyLabelAppearance)
            self._thumbnailPlaceholderColor = Trackable(reference: reference, referencePath: \.thumbnailPlaceholderColor)
            self._channelDateFormatter = Trackable(reference: reference, referencePath: \.channelDateFormatter)
            super.init(
                titleLabelAppearance: titleLabelAppearance ?? reference.titleLabelAppearance,
                subtitleLabelAppearance: subtitleLabelAppearance ?? reference.subtitleLabelAppearance,
                titleFormatter: titleFormatter ?? reference.titleFormatter,
                subtitleFormatter: titleFormatter ?? reference.subtitleFormatter,
                avatarRenderer: avatarRenderer ?? reference.avatarRenderer,
                avatarAppearance: avatarAppearance ?? reference.avatarAppearance
            )

            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let dateLabelAppearance { self.dateLabelAppearance = dateLabelAppearance }
            if let senderNameLabelAppearance { self.senderNameLabelAppearance = senderNameLabelAppearance }
            if let highlightedBodyLabelAppearance { self.highlightedBodyLabelAppearance = highlightedBodyLabelAppearance }
            if let thumbnailPlaceholderColor { self.thumbnailPlaceholderColor = thumbnailPlaceholderColor }
            if let channelDateFormatter { self.channelDateFormatter = channelDateFormatter }
        }
    }
}
