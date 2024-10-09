//
//  ChannelInfoViewController+VideoAttachmentCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.VideoAttachmentCell: AppearanceProviding {
    public static var appearance = Appearance(
        videoDurationIcon: nil,  // Default icon for video duration, can be overridden
        durationLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12),
            backgroundColor: .overlayBackground2
        ),
        durationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIImage?>
        public var videoDurationIcon: UIImage?  // Optional video duration icon
        
        @Trackable<Appearance, LabelAppearance>
        public var durationLabelAppearance: LabelAppearance  // Appearance settings for the duration label
        
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var durationFormatter: any TimeIntervalFormatting  // Formatter for video duration
        
        /// Initializer with explicit values
        public init(
            videoDurationIcon: UIImage?,
            durationLabelAppearance: LabelAppearance,
            durationFormatter: any TimeIntervalFormatting
        ) {
            self._videoDurationIcon = Trackable(value: videoDurationIcon)
            self._durationLabelAppearance = Trackable(value: durationLabelAppearance)
            self._durationFormatter = Trackable(value: durationFormatter)
        }
        
        /// Initializer with optional overrides
        public init(
            reference: ChannelInfoViewController.VideoAttachmentCell.Appearance,
            videoDurationIcon: UIImage? = nil,
            durationLabelAppearance: LabelAppearance? = nil,
            durationFormatter: (any TimeIntervalFormatting)? = nil
        ) {
            self._videoDurationIcon = Trackable(reference: reference, referencePath: \.videoDurationIcon)
            self._durationLabelAppearance = Trackable(reference: reference, referencePath: \.durationLabelAppearance)
            self._durationFormatter = Trackable(reference: reference, referencePath: \.durationFormatter)
            
            // Apply overrides if provided
            if let videoDurationIcon { self.videoDurationIcon = videoDurationIcon }
            if let durationLabelAppearance { self.durationLabelAppearance = durationLabelAppearance }
            if let durationFormatter { self.durationFormatter = durationFormatter }
        }
    }
}
