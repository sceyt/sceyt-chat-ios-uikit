//
//  MessageInputViewController+MediaView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.SelectedMediaView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .background
        public var attachmentDurationLabelAppearance: LabelAppearance = .init(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12),
            backgroundColor: .overlayBackground2
        )
        public var removeAttachmentIcon: UIImage = .closeCircle
        public var fileAttachmentNameLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        )
        public var fileAttachmentSizeLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(11)
        )
        public var fileAttachmentBackgroundColor: UIColor = .surface1
        public var fileAttachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
        public var fileAttachmentSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.attachmentSizeFormatter
        public var attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .background,
            attachmentDurationLabelAppearance: LabelAppearance = .init(
                foregroundColor: .onPrimary,
                font: Fonts.regular.withSize(12),
                backgroundColor: .overlayBackground2
            ),
            removeAttachmentIcon: UIImage = .closeCircle,
            fileAttachmentNameLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            fileAttachmentSizeLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(11)
            ),
            fileAttachmentBackgroundColor: UIColor = .surface1,
            fileAttachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
            fileAttachmentSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.attachmentSizeFormatter,
            attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        ) {
            self.backgroundColor = backgroundColor
            self.attachmentDurationLabelAppearance = attachmentDurationLabelAppearance
            self.removeAttachmentIcon = removeAttachmentIcon
            self.fileAttachmentNameLabelAppearance = fileAttachmentNameLabelAppearance
            self.fileAttachmentSizeLabelAppearance = fileAttachmentSizeLabelAppearance
            self.fileAttachmentBackgroundColor = fileAttachmentBackgroundColor
            self.fileAttachmentIconProvider = fileAttachmentIconProvider
            self.fileAttachmentSizeFormatter = fileAttachmentSizeFormatter
            self.attachmentDurationFormatter = attachmentDurationFormatter
        }
    }
}
