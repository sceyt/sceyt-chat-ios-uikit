//
//  ChannelInfoViewController+FileCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.FileCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var selectedBackgroundColor: UIColor = .surface2
        public var fileNameLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        )
        public var subtitleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        )
        public var loaderAppearance: CircularProgressView.Appearance = .init(
            progressColor: .onPrimary,
            trackColor: .clear,
            backgroundColor: .accent,
            cancelIcon: .downloadStop,
            uploadIcon: nil,
            downloadIcon: .downloadStart
        )
        public var fileNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter
        public var subtitleFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.channelInfoVoiceSubtitleFormatter
        public var iconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
        
        public init(
            selectedBackgroundColor: UIColor = .surface2,
            fileNameLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            subtitleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            loaderAppearance: CircularProgressView.Appearance = .init(
                progressColor: .onPrimary,
                trackColor: .clear,
                backgroundColor: .accent,
                cancelIcon: .downloadStop,
                uploadIcon: nil,
                downloadIcon: .downloadStart
            ),
            fileNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter,
            subtitleFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.channelInfoVoiceSubtitleFormatter,
            iconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
        ) {
            self.selectedBackgroundColor = selectedBackgroundColor
            self.fileNameLabelAppearance = fileNameLabelAppearance
            self.subtitleLabelAppearance = subtitleLabelAppearance
            self.loaderAppearance = loaderAppearance
            self.fileNameFormatter = fileNameFormatter
            self.subtitleFormatter = subtitleFormatter
            self.iconProvider = iconProvider
        }
    }
}
