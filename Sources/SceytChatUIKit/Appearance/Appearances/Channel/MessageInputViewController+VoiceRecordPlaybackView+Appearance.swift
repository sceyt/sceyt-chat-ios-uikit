//
//  MessageInputViewController+VoiceRecordPlaybackView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.VoiceRecordPlaybackView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .background
        public lazy var closeIcon: UIImage = .audioPlayerCancel
        public lazy var playIcon: UIImage = .audioPlayerPlayGrey
        public lazy var pauseIcon: UIImage = .audioPlayerPauseGrey
        public lazy var sendVoiceIcon: UIImage = .messageSendAction
        public lazy var playerBackgroundColor: UIColor = .surface1
        public lazy var durationLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                         font: Fonts.regular.withSize(12))
        public lazy var audioWaveformViewAppearance: AudioWaveformView.Appearance = AudioWaveformView.appearance
        public lazy var durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .background,
            closeIcon: UIImage = .audioPlayerCancel,
            playIcon: UIImage = .audioPlayerPlayGrey,
            pauseIcon: UIImage = .audioPlayerPauseGrey,
            sendVoiceIcon: UIImage = .messageSendAction,
            playerBackgroundColor: UIColor = .surface1,
            durationLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                             font: Fonts.regular.withSize(12)),
            audioWaveformViewAppearance: AudioWaveformView.Appearance = AudioWaveformView.appearance,
            durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        ) {
            self.backgroundColor = backgroundColor
            self.closeIcon = closeIcon
            self.playIcon = playIcon
            self.pauseIcon = pauseIcon
            self.sendVoiceIcon = sendVoiceIcon
            self.playerBackgroundColor = playerBackgroundColor
            self.durationLabelAppearance = durationLabelAppearance
            self.audioWaveformViewAppearance = audioWaveformViewAppearance
            self.durationFormatter = durationFormatter
        }
    }
}
