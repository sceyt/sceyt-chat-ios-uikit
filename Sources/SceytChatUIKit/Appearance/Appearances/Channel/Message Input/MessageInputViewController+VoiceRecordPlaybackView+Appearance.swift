//
//  MessageInputViewController+VoiceRecordPlaybackView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.VoiceRecordPlaybackView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        closeIcon: .audioPlayerCancel,
        playIcon: .audioPlayerPlayGrey,
        pauseIcon: .audioPlayerPauseGrey,
        sendVoiceIcon: .messageSendAction,
        playerBackgroundColor: .surface1,
        durationLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(12)
        ),
        audioWaveformViewAppearance: AudioWaveformView.appearance,
        durationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIImage>
        public var closeIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var playIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var pauseIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var sendVoiceIcon: UIImage
        
        @Trackable<Appearance, UIColor>
        public var playerBackgroundColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var durationLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, AudioWaveformView.Appearance>
        public var audioWaveformViewAppearance: AudioWaveformView.Appearance
        
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var durationFormatter: any TimeIntervalFormatting
        
        public init(
            backgroundColor: UIColor,
            closeIcon: UIImage,
            playIcon: UIImage,
            pauseIcon: UIImage,
            sendVoiceIcon: UIImage,
            playerBackgroundColor: UIColor,
            durationLabelAppearance: LabelAppearance,
            audioWaveformViewAppearance: AudioWaveformView.Appearance,
            durationFormatter: any TimeIntervalFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._closeIcon = Trackable(value: closeIcon)
            self._playIcon = Trackable(value: playIcon)
            self._pauseIcon = Trackable(value: pauseIcon)
            self._sendVoiceIcon = Trackable(value: sendVoiceIcon)
            self._playerBackgroundColor = Trackable(value: playerBackgroundColor)
            self._durationLabelAppearance = Trackable(value: durationLabelAppearance)
            self._audioWaveformViewAppearance = Trackable(value: audioWaveformViewAppearance)
            self._durationFormatter = Trackable(value: durationFormatter)
        }
        
        public init(
            reference: MessageInputViewController.VoiceRecordPlaybackView.Appearance,
            backgroundColor: UIColor? = nil,
            closeIcon: UIImage? = nil,
            playIcon: UIImage? = nil,
            pauseIcon: UIImage? = nil,
            sendVoiceIcon: UIImage? = nil,
            playerBackgroundColor: UIColor? = nil,
            durationLabelAppearance: LabelAppearance? = nil,
            audioWaveformViewAppearance: AudioWaveformView.Appearance? = nil,
            durationFormatter: (any TimeIntervalFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._closeIcon = Trackable(reference: reference, referencePath: \.closeIcon)
            self._playIcon = Trackable(reference: reference, referencePath: \.playIcon)
            self._pauseIcon = Trackable(reference: reference, referencePath: \.pauseIcon)
            self._sendVoiceIcon = Trackable(reference: reference, referencePath: \.sendVoiceIcon)
            self._playerBackgroundColor = Trackable(reference: reference, referencePath: \.playerBackgroundColor)
            self._durationLabelAppearance = Trackable(reference: reference, referencePath: \.durationLabelAppearance)
            self._audioWaveformViewAppearance = Trackable(reference: reference, referencePath: \.audioWaveformViewAppearance)
            self._durationFormatter = Trackable(reference: reference, referencePath: \.durationFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let closeIcon { self.closeIcon = closeIcon }
            if let playIcon { self.playIcon = playIcon }
            if let pauseIcon { self.pauseIcon = pauseIcon }
            if let sendVoiceIcon { self.sendVoiceIcon = sendVoiceIcon }
            if let playerBackgroundColor { self.playerBackgroundColor = playerBackgroundColor }
            if let durationLabelAppearance { self.durationLabelAppearance = durationLabelAppearance }
            if let audioWaveformViewAppearance { self.audioWaveformViewAppearance = audioWaveformViewAppearance }
            if let durationFormatter { self.durationFormatter = durationFormatter }
        }
    }
}
