//
//  ChannelInfoViewController+VoiceCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.VoiceCell: AppearanceProviding {
    public static var appearance = Appearance(
        playIcon: .audioPlayerPlay,
        pauseIcon: .audioPlayerPause,
        userNameLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        durationLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
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
        userNameFormatter: SceytChatUIKit.shared.formatters.userNameFormatter,
        subtitleFormatter: SceytChatUIKit.shared.formatters.channelInfoVoiceSubtitleFormatter,
        durationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIImage>
        public var playIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var pauseIcon: UIImage
        
        @Trackable<Appearance, LabelAppearance>
        public var userNameLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var subtitleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var durationLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, CircularProgressView.Appearance>
        public var loaderAppearance: CircularProgressView.Appearance
        
        @Trackable<Appearance, any UserFormatting>
        public var userNameFormatter: any UserFormatting
        
        @Trackable<Appearance, any AttachmentFormatting>
        public var subtitleFormatter: any AttachmentFormatting
        
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var durationFormatter: any TimeIntervalFormatting
        
        public init(
            playIcon: UIImage,
            pauseIcon: UIImage,
            userNameLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            durationLabelAppearance: LabelAppearance,
            loaderAppearance: CircularProgressView.Appearance,
            userNameFormatter: any UserFormatting,
            subtitleFormatter: any AttachmentFormatting,
            durationFormatter: any TimeIntervalFormatting
        ) {
            self._playIcon = Trackable(value: playIcon)
            self._pauseIcon = Trackable(value: pauseIcon)
            self._userNameLabelAppearance = Trackable(value: userNameLabelAppearance)
            self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
            self._durationLabelAppearance = Trackable(value: durationLabelAppearance)
            self._loaderAppearance = Trackable(value: loaderAppearance)
            self._userNameFormatter = Trackable(value: userNameFormatter)
            self._subtitleFormatter = Trackable(value: subtitleFormatter)
            self._durationFormatter = Trackable(value: durationFormatter)
        }
        
        public init(
            reference: ChannelInfoViewController.VoiceCell.Appearance,
            playIcon: UIImage? = nil,
            pauseIcon: UIImage? = nil,
            userNameLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            durationLabelAppearance: LabelAppearance? = nil,
            loaderAppearance: CircularProgressView.Appearance? = nil,
            userNameFormatter: (any UserFormatting)? = nil,
            subtitleFormatter: (any AttachmentFormatting)? = nil,
            durationFormatter: (any TimeIntervalFormatting)? = nil
        ) {
            self._playIcon = Trackable(reference: reference, referencePath: \.playIcon)
            self._pauseIcon = Trackable(reference: reference, referencePath: \.pauseIcon)
            self._userNameLabelAppearance = Trackable(reference: reference, referencePath: \.userNameLabelAppearance)
            self._subtitleLabelAppearance = Trackable(reference: reference, referencePath: \.subtitleLabelAppearance)
            self._durationLabelAppearance = Trackable(reference: reference, referencePath: \.durationLabelAppearance)
            self._loaderAppearance = Trackable(reference: reference, referencePath: \.loaderAppearance)
            self._userNameFormatter = Trackable(reference: reference, referencePath: \.userNameFormatter)
            self._subtitleFormatter = Trackable(reference: reference, referencePath: \.subtitleFormatter)
            self._durationFormatter = Trackable(reference: reference, referencePath: \.durationFormatter)
            
            if let playIcon { self.playIcon = playIcon }
            if let pauseIcon { self.pauseIcon = pauseIcon }
            if let userNameLabelAppearance { self.userNameLabelAppearance = userNameLabelAppearance }
            if let subtitleLabelAppearance { self.subtitleLabelAppearance = subtitleLabelAppearance }
            if let durationLabelAppearance { self.durationLabelAppearance = durationLabelAppearance }
            if let loaderAppearance { self.loaderAppearance = loaderAppearance }
            if let userNameFormatter { self.userNameFormatter = userNameFormatter }
            if let subtitleFormatter { self.subtitleFormatter = subtitleFormatter }
            if let durationFormatter { self.durationFormatter = durationFormatter }
        }
    }
}
