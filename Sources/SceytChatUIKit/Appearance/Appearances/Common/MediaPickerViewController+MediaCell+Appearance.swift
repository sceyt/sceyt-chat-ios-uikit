//
//  MediaPickerViewController+MediaCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MediaPickerViewController.MediaCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor
        public var videoDurationLabelAppearance: LabelAppearance
        public var videoDurationIcon: UIImage
        public var brokenMediaPlaceholderIcon: UIImage?
        public var durationFormatter: any TimeIntervalFormatting
        public var checkboxAppearance: CheckBoxView.Appearance
        
        public init(
            backgroundColor: UIColor = .surface1,
            videoDurationLabelAppearance: LabelAppearance = .init(
                foregroundColor: .onPrimary,
                font: Fonts.regular.withSize(12),
                backgroundColor: .overlayBackground2
            ),
            videoDurationIcon: UIImage = .galleryVideoAsset,
            brokenMediaPlaceholderIcon: UIImage? = AssetComposer.shared.compose(
                from: .init(
                    image: UIImage(systemName: "photo.badge.exclamationmark.fill")!,
                    renderingMode: .template(.accent)
                ),
                maxSize: .init(width: 60, height: 60)
            ),
            checkboxAppearance: CheckBoxView.Appearance = CheckBoxView.appearance,
            durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        ) {
            self.backgroundColor = backgroundColor
            self.videoDurationLabelAppearance = videoDurationLabelAppearance
            self.videoDurationIcon = videoDurationIcon
            self.brokenMediaPlaceholderIcon = brokenMediaPlaceholderIcon
            self.checkboxAppearance = checkboxAppearance
            self.durationFormatter = durationFormatter
        }
    }
}
