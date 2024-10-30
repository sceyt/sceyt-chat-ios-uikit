//
//  MediaPreviewerViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
extension MediaPreviewerViewController: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: DefaultColors.backgroundDark,
        videoControllerBackgroundColor: DefaultColors.backgroundDark,
        navigationBarAppearance: .init(
            reference: NavigationBarAppearance.appearance,
            tintColor: .onPrimary,
            standardAppearance: {
                let appearance = UINavigationBarAppearance()
                appearance.titleTextAttributes = [
                    .font: Fonts.bold.withSize(20),
                    .foregroundColor: UIColor.primaryText
                ]
                appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
                appearance.backgroundColor = DefaultColors.backgroundDark
                appearance.shadowColor = .clear
                return appearance
            }(),
            scrollEdgeAppearance: {
                let appearance = UINavigationBarAppearance()
                appearance.titleTextAttributes = [
                    .font: Fonts.bold.withSize(20),
                    .foregroundColor: UIColor.primaryText
                ]
                appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
                appearance.backgroundColor = DefaultColors.backgroundDark
                appearance.shadowColor = .clear
                return appearance
            }()
        ),
        playIcon: .videoPlayerPlay,
        pauseIcon: .videoPlayerPause,
        trackColor: .surface3,
        progressColor: .onPrimary,
        thumbColor: .onPrimary,
        titleLabelAppearance: .init(
            foregroundColor: .onPrimary,
            font: Fonts.bold.withSize(16)
        ),
        subtitleLabelAppearance: .init(
            foregroundColor: .onPrimary.withAlphaComponent(0.5),
            font: Fonts.regular.withSize(13)
        ),
        timelineLabelAppearance: .init(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(13)
        ),
        mediaLoaderAppearance: CircularProgressView.appearance,
        userNameFormatter: SceytChatUIKit.shared.formatters.userNameFormatter,
        mediaDateFormatter: SceytChatUIKit.shared.formatters.mediaPreviewDateFormatter,
        durationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var videoControllerBackgroundColor: UIColor
        
        @Trackable<Appearance, NavigationBarAppearance>
        public var navigationBarAppearance: NavigationBarAppearance
        
        @Trackable<Appearance, UIImage>
        public var playIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var pauseIcon: UIImage
        
        @Trackable<Appearance, UIColor>
        public var trackColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var progressColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var thumbColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var subtitleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var timelineLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, CircularProgressView.Appearance>
        public var mediaLoaderAppearance: CircularProgressView.Appearance
        
        @Trackable<Appearance, any UserFormatting>
        public var userNameFormatter: any UserFormatting
        
        @Trackable<Appearance, any DateFormatting>
        public var mediaDateFormatter: any DateFormatting
        
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var durationFormatter: any TimeIntervalFormatting
        
        public init(
            backgroundColor: UIColor,
            videoControllerBackgroundColor: UIColor,
            navigationBarAppearance: NavigationBarAppearance,
            playIcon: UIImage,
            pauseIcon: UIImage,
            trackColor: UIColor,
            progressColor: UIColor,
            thumbColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            subtitleLabelAppearance: LabelAppearance,
            timelineLabelAppearance: LabelAppearance,
            mediaLoaderAppearance: CircularProgressView.Appearance,
            userNameFormatter: any UserFormatting,
            mediaDateFormatter: any DateFormatting,
            durationFormatter: any TimeIntervalFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._videoControllerBackgroundColor = Trackable(value: videoControllerBackgroundColor)
            self._navigationBarAppearance = Trackable(value: navigationBarAppearance)
            self._playIcon = Trackable(value: playIcon)
            self._pauseIcon = Trackable(value: pauseIcon)
            self._trackColor = Trackable(value: trackColor)
            self._progressColor = Trackable(value: progressColor)
            self._thumbColor = Trackable(value: thumbColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
            self._timelineLabelAppearance = Trackable(value: timelineLabelAppearance)
            self._mediaLoaderAppearance = Trackable(value: mediaLoaderAppearance)
            self._userNameFormatter = Trackable(value: userNameFormatter)
            self._mediaDateFormatter = Trackable(value: mediaDateFormatter)
            self._durationFormatter = Trackable(value: durationFormatter)
        }
        
        public init(
            reference: MediaPreviewerViewController.Appearance,
            backgroundColor: UIColor? = nil,
            videoControllerBackgroundColor: UIColor? = nil,
            navigationBarAppearance: NavigationBarAppearance? = nil,
            playIcon: UIImage? = nil,
            pauseIcon: UIImage? = nil,
            trackColor: UIColor? = nil,
            progressColor: UIColor? = nil,
            thumbColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            subtitleLabelAppearance: LabelAppearance? = nil,
            timelineLabelAppearance: LabelAppearance? = nil,
            mediaLoaderAppearance: CircularProgressView.Appearance? = nil,
            userNameFormatter: (any UserFormatting)? = nil,
            mediaDateFormatter: (any DateFormatting)? = nil,
            durationFormatter: (any TimeIntervalFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._videoControllerBackgroundColor = Trackable(reference: reference, referencePath: \.videoControllerBackgroundColor)
            self._navigationBarAppearance = Trackable(reference: reference, referencePath: \.navigationBarAppearance)
            self._playIcon = Trackable(reference: reference, referencePath: \.playIcon)
            self._pauseIcon = Trackable(reference: reference, referencePath: \.pauseIcon)
            self._trackColor = Trackable(reference: reference, referencePath: \.trackColor)
            self._progressColor = Trackable(reference: reference, referencePath: \.progressColor)
            self._thumbColor = Trackable(reference: reference, referencePath: \.thumbColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._subtitleLabelAppearance = Trackable(reference: reference, referencePath: \.subtitleLabelAppearance)
            self._timelineLabelAppearance = Trackable(reference: reference, referencePath: \.timelineLabelAppearance)
            self._mediaLoaderAppearance = Trackable(reference: reference, referencePath: \.mediaLoaderAppearance)
            self._userNameFormatter = Trackable(reference: reference, referencePath: \.userNameFormatter)
            self._mediaDateFormatter = Trackable(reference: reference, referencePath: \.mediaDateFormatter)
            self._durationFormatter = Trackable(reference: reference, referencePath: \.durationFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let videoControllerBackgroundColor { self.videoControllerBackgroundColor = videoControllerBackgroundColor }
            if let navigationBarAppearance { self.navigationBarAppearance = navigationBarAppearance }
            if let playIcon { self.playIcon = playIcon }
            if let pauseIcon { self.pauseIcon = pauseIcon }
            if let trackColor { self.trackColor = trackColor }
            if let progressColor { self.progressColor = progressColor }
            if let thumbColor { self.thumbColor = thumbColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let subtitleLabelAppearance { self.subtitleLabelAppearance = subtitleLabelAppearance }
            if let timelineLabelAppearance { self.timelineLabelAppearance = timelineLabelAppearance }
            if let mediaLoaderAppearance { self.mediaLoaderAppearance = mediaLoaderAppearance }
            if let userNameFormatter { self.userNameFormatter = userNameFormatter }
            if let mediaDateFormatter { self.mediaDateFormatter = mediaDateFormatter }
            if let durationFormatter { self.durationFormatter = durationFormatter }
        }
    }
}
