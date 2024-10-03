//
//  ChannelInfoViewController+VoiceCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.VoiceCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var playIcon: UIImage = .audioPlayerPlay
        public var pauseIcon: UIImage = .audioPlayerPause
        public var userNameLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        )
        public var subtitleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        )
        public var durationLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
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
        public var userNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
        public var subtitleFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.channelInfoVoiceSubtitleFormatter
        public var durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        
        public init(
            playIcon: UIImage = .audioPlayerPlay,
            pauseIcon: UIImage = .audioPlayerPause,
            userNameLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(16)
            ),
            subtitleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            durationLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
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
            userNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter,
            subtitleFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.channelInfoVoiceSubtitleFormatter,
            durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        ) {
            self.playIcon = playIcon
            self.pauseIcon = pauseIcon
            self.userNameLabelAppearance = userNameLabelAppearance
            self.subtitleLabelAppearance = subtitleLabelAppearance
            self.durationLabelAppearance = durationLabelAppearance
            self.loaderAppearance = loaderAppearance
            self.userNameFormatter = userNameFormatter
            self.subtitleFormatter = subtitleFormatter
            self.durationFormatter = durationFormatter
        }
    }
}
