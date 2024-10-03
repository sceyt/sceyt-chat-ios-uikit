//
//  MessageInputViewController+VoiceRecorderView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.VoiceRecorderView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor = .background
        public var dividerColor: UIColor = .border // should be removed after restructuring views
        public var durationLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        )
        public var slideToCancelTextStyleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(16)
        )
        public var slideToCancelText: String = L10n.Recorder.slideToCancel
        public var cancelLabelAppearance: LabelAppearance = .init(
            foregroundColor: .stateWarning,
            font: Fonts.regular.withSize(16)
        )
        public var cancelText: String = L10n.Recorder.cancel
        public var recordingIndicatorColor: UIColor = DefaultColors.defaultRed
        public var recordingIcon: UIImage = .audioPlayerMicGreen
        public var deleteRecordIcon: UIImage = .audioPlayerDelete
        public var unlockedIcon: UIImage = .audioPlayerUnlock
        public var lockedIcon: UIImage = .audioPlayerLock
        public var stopRecordingIcon: UIImage = .audioPlayerStop
        public var sendVoiceIcon: UIImage = .audioPlayerSendLarge
        public var durationFormatter: TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .background,
            dividerColor: UIColor = .border,
            durationLabelAppearance: LabelAppearance = .init(
                foregroundColor: .primaryText,
                font: Fonts.regular.withSize(16)
            ),
            slideToCancelTextStyleLabelAppearance: LabelAppearance = .init(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(16)
            ),
            slideToCancelText: String = L10n.Recorder.slideToCancel,
            cancelLabelAppearance: LabelAppearance = .init(
                foregroundColor: .stateWarning,
                font: Fonts.regular.withSize(16)
            ),
            cancelText: String = L10n.Recorder.cancel,
            recordingIndicatorColor: UIColor = DefaultColors.defaultRed,
            recordingIcon: UIImage = .audioPlayerMicGreen,
            deleteRecordIcon: UIImage = .audioPlayerDelete,
            unlockedIcon: UIImage = .audioPlayerUnlock,
            lockedIcon: UIImage = .audioPlayerLock,
            stopRecordingIcon: UIImage = .audioPlayerStop,
            sendVoiceIcon: UIImage = .audioPlayerSendLarge,
            durationFormatter: TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        ) {
            self.backgroundColor = backgroundColor
            self.dividerColor = dividerColor
            self.durationLabelAppearance = durationLabelAppearance
            self.slideToCancelTextStyleLabelAppearance = slideToCancelTextStyleLabelAppearance
            self.slideToCancelText = slideToCancelText
            self.cancelLabelAppearance = cancelLabelAppearance
            self.cancelText = cancelText
            self.recordingIndicatorColor = recordingIndicatorColor
            self.recordingIcon = recordingIcon
            self.deleteRecordIcon = deleteRecordIcon
            self.unlockedIcon = unlockedIcon
            self.lockedIcon = lockedIcon
            self.stopRecordingIcon = stopRecordingIcon
            self.sendVoiceIcon = sendVoiceIcon
            self.durationFormatter = durationFormatter
        }
    }
}
