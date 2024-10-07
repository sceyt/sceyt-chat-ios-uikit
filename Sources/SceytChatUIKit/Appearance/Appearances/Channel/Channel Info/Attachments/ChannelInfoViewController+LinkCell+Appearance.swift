//
//  ChannelInfoViewController+LinkCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.LinkCell: AppearanceProviding {
    public static var appearance = Appearance(
        selectedBackgroundColor: .surface2,
        linkLabelAppearance: LabelAppearance(
            foregroundColor: .systemBlue,
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
        public var selectedBackgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var linkLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LinkPreviewAppearance>
        public var linkPreviewAppearance: LinkPreviewAppearance
        
        public init(
            selectedBackgroundColor: UIColor,
            linkLabelAppearance: LabelAppearance,
            linkPreviewAppearance: LinkPreviewAppearance
        ) {
            self._selectedBackgroundColor = Trackable(value: selectedBackgroundColor)
            self._linkLabelAppearance = Trackable(value: linkLabelAppearance)
            self._linkPreviewAppearance = Trackable(value: linkPreviewAppearance)
        }
        
        public init(
            reference: ChannelInfoViewController.LinkCell.Appearance,
            selectedBackgroundColor: UIColor? = nil,
            linkLabelAppearance: LabelAppearance? = nil,
            linkPreviewAppearance: LinkPreviewAppearance? = nil
        ) {
            self._selectedBackgroundColor = Trackable(reference: reference, referencePath: \.selectedBackgroundColor)
            self._linkLabelAppearance = Trackable(reference: reference, referencePath: \.linkLabelAppearance)
            self._linkPreviewAppearance = Trackable(reference: reference, referencePath: \.linkPreviewAppearance)
            
            if let selectedBackgroundColor { self.selectedBackgroundColor = selectedBackgroundColor }
            if let linkLabelAppearance { self.linkLabelAppearance = linkLabelAppearance }
            if let linkPreviewAppearance { self.linkPreviewAppearance = linkPreviewAppearance }
        }
    }
}
