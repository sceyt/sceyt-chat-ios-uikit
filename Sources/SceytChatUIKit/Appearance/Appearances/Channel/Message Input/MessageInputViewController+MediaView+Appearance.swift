//
//  MessageInputViewController+MediaView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.SelectedMediaView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        attachmentDurationLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12),
            backgroundColor: .overlayBackground2
        ),
        removeAttachmentIcon: .closeCircle,
        fileAttachmentNameLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        fileAttachmentSizeLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(11)
        ),
        fileAttachmentBackgroundColor: .surface1,
        fileAttachmentIconProvider: SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
        fileAttachmentSizeFormatter: SceytChatUIKit.shared.formatters.attachmentSizeFormatter,
        attachmentDurationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var attachmentDurationLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIImage>
        public var removeAttachmentIcon: UIImage
        
        @Trackable<Appearance, LabelAppearance>
        public var fileAttachmentNameLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var fileAttachmentSizeLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, UIColor>
        public var fileAttachmentBackgroundColor: UIColor
        
        @Trackable<Appearance, any AttachmentIconProviding>
        public var fileAttachmentIconProvider: any AttachmentIconProviding
        
        @Trackable<Appearance, any UIntFormatting>
        public var fileAttachmentSizeFormatter: any UIntFormatting
        
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var attachmentDurationFormatter: any TimeIntervalFormatting
        
        public init(
            backgroundColor: UIColor,
            attachmentDurationLabelAppearance: LabelAppearance,
            removeAttachmentIcon: UIImage,
            fileAttachmentNameLabelAppearance: LabelAppearance,
            fileAttachmentSizeLabelAppearance: LabelAppearance,
            fileAttachmentBackgroundColor: UIColor,
            fileAttachmentIconProvider: any AttachmentIconProviding,
            fileAttachmentSizeFormatter: any UIntFormatting,
            attachmentDurationFormatter: any TimeIntervalFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._attachmentDurationLabelAppearance = Trackable(value: attachmentDurationLabelAppearance)
            self._removeAttachmentIcon = Trackable(value: removeAttachmentIcon)
            self._fileAttachmentNameLabelAppearance = Trackable(value: fileAttachmentNameLabelAppearance)
            self._fileAttachmentSizeLabelAppearance = Trackable(value: fileAttachmentSizeLabelAppearance)
            self._fileAttachmentBackgroundColor = Trackable(value: fileAttachmentBackgroundColor)
            self._fileAttachmentIconProvider = Trackable(value: fileAttachmentIconProvider)
            self._fileAttachmentSizeFormatter = Trackable(value: fileAttachmentSizeFormatter)
            self._attachmentDurationFormatter = Trackable(value: attachmentDurationFormatter)
        }
        
        public init(
            reference: MessageInputViewController.SelectedMediaView.Appearance,
            backgroundColor: UIColor? = nil,
            attachmentDurationLabelAppearance: LabelAppearance? = nil,
            removeAttachmentIcon: UIImage? = nil,
            fileAttachmentNameLabelAppearance: LabelAppearance? = nil,
            fileAttachmentSizeLabelAppearance: LabelAppearance? = nil,
            fileAttachmentBackgroundColor: UIColor? = nil,
            fileAttachmentIconProvider: (any AttachmentIconProviding)? = nil,
            fileAttachmentSizeFormatter: (any UIntFormatting)? = nil,
            attachmentDurationFormatter: (any TimeIntervalFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._attachmentDurationLabelAppearance = Trackable(reference: reference, referencePath: \.attachmentDurationLabelAppearance)
            self._removeAttachmentIcon = Trackable(reference: reference, referencePath: \.removeAttachmentIcon)
            self._fileAttachmentNameLabelAppearance = Trackable(reference: reference, referencePath: \.fileAttachmentNameLabelAppearance)
            self._fileAttachmentSizeLabelAppearance = Trackable(reference: reference, referencePath: \.fileAttachmentSizeLabelAppearance)
            self._fileAttachmentBackgroundColor = Trackable(reference: reference, referencePath: \.fileAttachmentBackgroundColor)
            self._fileAttachmentIconProvider = Trackable(reference: reference, referencePath: \.fileAttachmentIconProvider)
            self._fileAttachmentSizeFormatter = Trackable(reference: reference, referencePath: \.fileAttachmentSizeFormatter)
            self._attachmentDurationFormatter = Trackable(reference: reference, referencePath: \.attachmentDurationFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let attachmentDurationLabelAppearance { self.attachmentDurationLabelAppearance = attachmentDurationLabelAppearance }
            if let removeAttachmentIcon { self.removeAttachmentIcon = removeAttachmentIcon }
            if let fileAttachmentNameLabelAppearance { self.fileAttachmentNameLabelAppearance = fileAttachmentNameLabelAppearance }
            if let fileAttachmentSizeLabelAppearance { self.fileAttachmentSizeLabelAppearance = fileAttachmentSizeLabelAppearance }
            if let fileAttachmentBackgroundColor { self.fileAttachmentBackgroundColor = fileAttachmentBackgroundColor }
            if let fileAttachmentIconProvider { self.fileAttachmentIconProvider = fileAttachmentIconProvider }
            if let fileAttachmentSizeFormatter { self.fileAttachmentSizeFormatter = fileAttachmentSizeFormatter }
            if let attachmentDurationFormatter { self.attachmentDurationFormatter = attachmentDurationFormatter }
        }
    }
}
