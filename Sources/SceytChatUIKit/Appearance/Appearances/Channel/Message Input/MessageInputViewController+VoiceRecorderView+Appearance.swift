//
//  MessageInputViewController+VoiceRecorderView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.VoiceRecorderView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .background,
        dividerColor: .border,
        durationLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        slideToCancelTextStyleLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(16)
        ),
        slideToCancelText: L10n.Recorder.slideToCancel,
        cancelLabelAppearance: LabelAppearance(
            foregroundColor: .stateWarning,
            font: Fonts.regular.withSize(16)
        ),
        cancelText: L10n.Recorder.cancel,
        recordingIndicatorColor: DefaultColors.defaultRed,
        recordingIcon: .audioPlayerMicGreen,
        deleteRecordIcon: .audioPlayerDelete,
        unlockedIcon: .audioPlayerUnlock,
        lockedIcon: .audioPlayerLock,
        stopRecordingIcon: .audioPlayerStop,
        sendVoiceIcon: .audioPlayerSendLarge,
        durationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter
    )
    
    public struct Appearance {
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var dividerColor: UIColor
        
        @Trackable<Appearance, LabelAppearance>
        public var durationLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var slideToCancelTextStyleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, String>
        public var slideToCancelText: String
        
        @Trackable<Appearance, LabelAppearance>
        public var cancelLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, String>
        public var cancelText: String
        
        @Trackable<Appearance, UIColor>
        public var recordingIndicatorColor: UIColor
        
        @Trackable<Appearance, UIImage>
        public var recordingIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var deleteRecordIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var unlockedIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var lockedIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var stopRecordingIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var sendVoiceIcon: UIImage
        
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var durationFormatter: any TimeIntervalFormatting
        
        public init(
            backgroundColor: UIColor,
            dividerColor: UIColor,
            durationLabelAppearance: LabelAppearance,
            slideToCancelTextStyleLabelAppearance: LabelAppearance,
            slideToCancelText: String,
            cancelLabelAppearance: LabelAppearance,
            cancelText: String,
            recordingIndicatorColor: UIColor,
            recordingIcon: UIImage,
            deleteRecordIcon: UIImage,
            unlockedIcon: UIImage,
            lockedIcon: UIImage,
            stopRecordingIcon: UIImage,
            sendVoiceIcon: UIImage,
            durationFormatter: any TimeIntervalFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._dividerColor = Trackable(value: dividerColor)
            self._durationLabelAppearance = Trackable(value: durationLabelAppearance)
            self._slideToCancelTextStyleLabelAppearance = Trackable(value: slideToCancelTextStyleLabelAppearance)
            self._slideToCancelText = Trackable(value: slideToCancelText)
            self._cancelLabelAppearance = Trackable(value: cancelLabelAppearance)
            self._cancelText = Trackable(value: cancelText)
            self._recordingIndicatorColor = Trackable(value: recordingIndicatorColor)
            self._recordingIcon = Trackable(value: recordingIcon)
            self._deleteRecordIcon = Trackable(value: deleteRecordIcon)
            self._unlockedIcon = Trackable(value: unlockedIcon)
            self._lockedIcon = Trackable(value: lockedIcon)
            self._stopRecordingIcon = Trackable(value: stopRecordingIcon)
            self._sendVoiceIcon = Trackable(value: sendVoiceIcon)
            self._durationFormatter = Trackable(value: durationFormatter)
        }
        
        public init(
            reference: MessageInputViewController.VoiceRecorderView.Appearance,
            backgroundColor: UIColor? = nil,
            dividerColor: UIColor? = nil,
            durationLabelAppearance: LabelAppearance? = nil,
            slideToCancelTextStyleLabelAppearance: LabelAppearance? = nil,
            slideToCancelText: String? = nil,
            cancelLabelAppearance: LabelAppearance? = nil,
            cancelText: String? = nil,
            recordingIndicatorColor: UIColor? = nil,
            recordingIcon: UIImage? = nil,
            deleteRecordIcon: UIImage? = nil,
            unlockedIcon: UIImage? = nil,
            lockedIcon: UIImage? = nil,
            stopRecordingIcon: UIImage? = nil,
            sendVoiceIcon: UIImage? = nil,
            durationFormatter: (any TimeIntervalFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._dividerColor = Trackable(reference: reference, referencePath: \.dividerColor)
            self._durationLabelAppearance = Trackable(reference: reference, referencePath: \.durationLabelAppearance)
            self._slideToCancelTextStyleLabelAppearance = Trackable(reference: reference, referencePath: \.slideToCancelTextStyleLabelAppearance)
            self._slideToCancelText = Trackable(reference: reference, referencePath: \.slideToCancelText)
            self._cancelLabelAppearance = Trackable(reference: reference, referencePath: \.cancelLabelAppearance)
            self._cancelText = Trackable(reference: reference, referencePath: \.cancelText)
            self._recordingIndicatorColor = Trackable(reference: reference, referencePath: \.recordingIndicatorColor)
            self._recordingIcon = Trackable(reference: reference, referencePath: \.recordingIcon)
            self._deleteRecordIcon = Trackable(reference: reference, referencePath: \.deleteRecordIcon)
            self._unlockedIcon = Trackable(reference: reference, referencePath: \.unlockedIcon)
            self._lockedIcon = Trackable(reference: reference, referencePath: \.lockedIcon)
            self._stopRecordingIcon = Trackable(reference: reference, referencePath: \.stopRecordingIcon)
            self._sendVoiceIcon = Trackable(reference: reference, referencePath: \.sendVoiceIcon)
            self._durationFormatter = Trackable(reference: reference, referencePath: \.durationFormatter)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let dividerColor { self.dividerColor = dividerColor }
            if let durationLabelAppearance { self.durationLabelAppearance = durationLabelAppearance }
            if let slideToCancelTextStyleLabelAppearance { self.slideToCancelTextStyleLabelAppearance = slideToCancelTextStyleLabelAppearance }
            if let slideToCancelText { self.slideToCancelText = slideToCancelText }
            if let cancelLabelAppearance { self.cancelLabelAppearance = cancelLabelAppearance }
            if let cancelText { self.cancelText = cancelText }
            if let recordingIndicatorColor { self.recordingIndicatorColor = recordingIndicatorColor }
            if let recordingIcon { self.recordingIcon = recordingIcon }
            if let deleteRecordIcon { self.deleteRecordIcon = deleteRecordIcon }
            if let unlockedIcon { self.unlockedIcon = unlockedIcon }
            if let lockedIcon { self.lockedIcon = lockedIcon }
            if let stopRecordingIcon { self.stopRecordingIcon = stopRecordingIcon }
            if let sendVoiceIcon { self.sendVoiceIcon = sendVoiceIcon }
            if let durationFormatter { self.durationFormatter = durationFormatter }
        }
    }
}
