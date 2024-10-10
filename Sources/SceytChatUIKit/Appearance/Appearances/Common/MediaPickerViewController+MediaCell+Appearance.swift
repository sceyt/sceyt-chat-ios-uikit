//
//  MediaPickerViewController+MediaCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MediaPickerViewController.MediaCell: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .surface1,
        videoDurationLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12),
            backgroundColor: .overlayBackground2
        ),
        videoDurationIcon: .galleryVideoAsset,
        brokenMediaPlaceholderIcon: .brokenImage,
        durationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        checkboxAppearance: CheckBoxView.appearance
    )
    
    public class Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var videoDurationLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIImage>
        public var videoDurationIcon: UIImage
        
        @Trackable<Appearance, UIImage?>
        public var brokenMediaPlaceholderIcon: UIImage?
        
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var durationFormatter: any TimeIntervalFormatting
        
        @Trackable<Appearance, CheckBoxView.Appearance>
        public var checkboxAppearance: CheckBoxView.Appearance
        
        // Primary Initializer with all parameters
        public init(
            backgroundColor: UIColor,
            videoDurationLabelAppearance: LabelAppearance,
            videoDurationIcon: UIImage,
            brokenMediaPlaceholderIcon: UIImage?,
            durationFormatter: any TimeIntervalFormatting,
            checkboxAppearance: CheckBoxView.Appearance
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._videoDurationLabelAppearance = Trackable(value: videoDurationLabelAppearance)
            self._videoDurationIcon = Trackable(value: videoDurationIcon)
            self._brokenMediaPlaceholderIcon = Trackable(value: brokenMediaPlaceholderIcon)
            self._durationFormatter = Trackable(value: durationFormatter)
            self._checkboxAppearance = Trackable(value: checkboxAppearance)
        }
        
        // Secondary Initializer with optional parameters
        public init(
            reference: MediaPickerViewController.MediaCell.Appearance,
            backgroundColor: UIColor? = nil,
            videoDurationLabelAppearance: LabelAppearance? = nil,
            videoDurationIcon: UIImage? = nil,
            brokenMediaPlaceholderIcon: UIImage? = nil,
            durationFormatter: (any TimeIntervalFormatting)? = nil,
            checkboxAppearance: CheckBoxView.Appearance? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._videoDurationLabelAppearance = Trackable(reference: reference, referencePath: \.videoDurationLabelAppearance)
            self._videoDurationIcon = Trackable(reference: reference, referencePath: \.videoDurationIcon)
            self._brokenMediaPlaceholderIcon = Trackable(reference: reference, referencePath: \.brokenMediaPlaceholderIcon)
            self._durationFormatter = Trackable(reference: reference, referencePath: \.durationFormatter)
            self._checkboxAppearance = Trackable(reference: reference, referencePath: \.checkboxAppearance)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let videoDurationLabelAppearance { self.videoDurationLabelAppearance = videoDurationLabelAppearance }
            if let videoDurationIcon { self.videoDurationIcon = videoDurationIcon }
            if let brokenMediaPlaceholderIcon { self.brokenMediaPlaceholderIcon = brokenMediaPlaceholderIcon }
            if let durationFormatter { self.durationFormatter = durationFormatter }
            if let checkboxAppearance { self.checkboxAppearance = checkboxAppearance }
        }
    }
}
