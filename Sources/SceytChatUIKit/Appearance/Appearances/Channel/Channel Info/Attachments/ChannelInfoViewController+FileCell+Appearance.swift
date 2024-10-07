//
//  ChannelInfoViewController+FileCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.FileCell: AppearanceProviding {
    public static var appearance = Appearance(
        selectedBackgroundColor: .surface2,
        fileNameLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        loaderAppearance: CircularProgressView.Appearance(
            reference: CircularProgressView.appearance,
            progressColor: .onPrimary,
            trackColor: .clear,
            backgroundColor: .accent,
            cancelIcon: .downloadStop,
            uploadIcon: nil,
            downloadIcon: .downloadStart
        ),
        fileNameFormatter: SceytChatUIKit.shared.formatters.attachmentNameFormatter,
        subtitleFormatter: SceytChatUIKit.shared.formatters.channelInfoVoiceSubtitleFormatter,
        iconProvider: SceytChatUIKit.shared.visualProviders.attachmentIconProvider
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var selectedBackgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var fileNameLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var subtitleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, CircularProgressView.Appearance>
        public var loaderAppearance: CircularProgressView.Appearance
        
        @Trackable<Appearance, any AttachmentFormatting>
        public var fileNameFormatter: any AttachmentFormatting
        
        @Trackable<Appearance, any AttachmentFormatting>
        public var subtitleFormatter: any AttachmentFormatting
        
        @Trackable<Appearance, any AttachmentIconProviding>
        public var iconProvider: any AttachmentIconProviding
        
        public init(
            selectedBackgroundColor: UIColor,
            fileNameLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            loaderAppearance: CircularProgressView.Appearance,
            fileNameFormatter: any AttachmentFormatting,
            subtitleFormatter: any AttachmentFormatting,
            iconProvider: any AttachmentIconProviding
        ) {
            self._selectedBackgroundColor = Trackable(value: selectedBackgroundColor)
            self._fileNameLabelAppearance = Trackable(value: fileNameLabelAppearance)
            self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
            self._loaderAppearance = Trackable(value: loaderAppearance)
            self._fileNameFormatter = Trackable(value: fileNameFormatter)
            self._subtitleFormatter = Trackable(value: subtitleFormatter)
            self._iconProvider = Trackable(value: iconProvider)
        }
        
        public init(
            reference: ChannelInfoViewController.FileCell.Appearance,
            selectedBackgroundColor: UIColor? = nil,
            fileNameLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            loaderAppearance: CircularProgressView.Appearance? = nil,
            fileNameFormatter: (any AttachmentFormatting)? = nil,
            subtitleFormatter: (any AttachmentFormatting)? = nil,
            iconProvider: (any AttachmentIconProviding)? = nil
        ) {
            self._selectedBackgroundColor = Trackable(reference: reference, referencePath: \.selectedBackgroundColor)
            self._fileNameLabelAppearance = Trackable(reference: reference, referencePath: \.fileNameLabelAppearance)
            self._subtitleLabelAppearance = Trackable(reference: reference, referencePath: \.subtitleLabelAppearance)
            self._loaderAppearance = Trackable(reference: reference, referencePath: \.loaderAppearance)
            self._fileNameFormatter = Trackable(reference: reference, referencePath: \.fileNameFormatter)
            self._subtitleFormatter = Trackable(reference: reference, referencePath: \.subtitleFormatter)
            self._iconProvider = Trackable(reference: reference, referencePath: \.iconProvider)
            
            if let selectedBackgroundColor { self.selectedBackgroundColor = selectedBackgroundColor }
            if let fileNameLabelAppearance { self.fileNameLabelAppearance = fileNameLabelAppearance }
            if let subtitleLabelAppearance { self.subtitleLabelAppearance = subtitleLabelAppearance }
            if let loaderAppearance { self.loaderAppearance = loaderAppearance }
            if let fileNameFormatter { self.fileNameFormatter = fileNameFormatter }
            if let subtitleFormatter { self.subtitleFormatter = subtitleFormatter }
            if let iconProvider { self.iconProvider = iconProvider }
        }
    }
}
