//
//  GlobalSearchLinkCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension GlobalSearchLinkCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .clear,
        separatorColor: .border,
        linkLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(14)
        ),
        linkPreviewAppearance: LinkPreviewAppearance(
            reference: LinkPreviewAppearance.appearance,
            titleLabelAppearance: LabelAppearance(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            descriptionLabelAppearance: LabelAppearance(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            placeholderIcon: .link
        )
    )

    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor

        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor

        @Trackable<Appearance, LabelAppearance>
        public var linkLabelAppearance: LabelAppearance

        @Trackable<Appearance, LinkPreviewAppearance>
        public var linkPreviewAppearance: LinkPreviewAppearance

        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            linkLabelAppearance: LabelAppearance,
            linkPreviewAppearance: LinkPreviewAppearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._linkLabelAppearance = Trackable(value: linkLabelAppearance)
            self._linkPreviewAppearance = Trackable(value: linkPreviewAppearance)
        }

        public init(
            reference: GlobalSearchLinkCell.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            linkLabelAppearance: LabelAppearance? = nil,
            linkPreviewAppearance: LinkPreviewAppearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._linkLabelAppearance = Trackable(reference: reference, referencePath: \.linkLabelAppearance)
            self._linkPreviewAppearance = Trackable(reference: reference, referencePath: \.linkPreviewAppearance)

            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let linkLabelAppearance { self.linkLabelAppearance = linkLabelAppearance }
            if let linkPreviewAppearance { self.linkPreviewAppearance = linkPreviewAppearance }
        }
    }
}
