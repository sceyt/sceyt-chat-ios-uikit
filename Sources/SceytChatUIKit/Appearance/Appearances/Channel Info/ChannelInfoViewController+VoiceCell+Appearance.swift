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
    
    public class Appearance {//}: CellAppearance<AnyUserFormatting, AnyDateFormatting, AnyAttachmentIconProviding> {
        
        public lazy var playIcon: UIImage = .audioPlayerPlay
        public lazy var pauseIcon: UIImage = .audioPlayerPause
        public lazy var userNameLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        )
        public lazy var dateLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        )
        public lazy var durationLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(13)
        )
        public lazy var loaderAppearance: CircularProgressView.Appearance = .init(
            progressColor: .onPrimary,
            trackColor: .clear,
            backgroundColor: .accent,
            cancelIcon: .downloadStop,
            uploadIcon: nil,
            downloadIcon: .downloadStart
        )
        public lazy var userNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
        public lazy var dateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.channelInfoAttachmentDateFormatter
        public lazy var durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        
        public init(
            playIcon: UIImage = .audioPlayerPlay,
            pauseIcon: UIImage = .audioPlayerPause,
            titleLabelAppearance: LabelAppearance = .init(
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
            loaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
                                                                      trackColor: .clear,
                                                                      backgroundColor: .accent,
                                                                      cancelIcon: .downloadStop,
                                                                      uploadIcon: nil,
                                                                      downloadIcon: .downloadStart),
            titleFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter,
            subtitleFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.channelInfoAttachmentDateFormatter,
            durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        ) {
            self.playIcon = playIcon
            self.pauseIcon = pauseIcon
            self.titleLabelAppearance = titleLabelAppearance
            self.subtitleLabelAppearance = subtitleLabelAppearance
            self.durationLabelAppearance = durationLabelAppearance
            self.loaderAppearance = loaderAppearance
            self.titleFormatter = titleFormatter
            self.subtitleFormatter = subtitleFormatter
            self.durationFormatter = durationFormatter
        }
    }
}
