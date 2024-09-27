//
//  MessageInputViewController+VoiceRecorderView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

extension MessageInputViewController.VoiceRecorderView: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .background
        public lazy var dividerColor: UIColor = .border // should be removed after restructuring views
        public lazy var durationLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                         font: Fonts.regular.withSize(16))
        public lazy var slideToCancelTextStyleLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                                       font: Fonts.regular.withSize(16))
        public lazy var slideToCancelText: String = L10n.Recorder.slideToCancel
        public lazy var cancelLabelAppearance: LabelAppearance = .init(foregroundColor: .stateWarning,
                                                                       font: Fonts.regular.withSize(16))
        public lazy var cancelText: String = L10n.Recorder.cancel
        public lazy var recordingIndicatorColor: UIColor = DefaultColors.defaultRed
        public lazy var recordingIcon: UIImage = .audioPlayerMicGreen
        public lazy var deleteRecordIcon: UIImage = .audioPlayerDelete
        public lazy var unlockedIcon: UIImage = .audioPlayerUnlock
        public lazy var lockedIcon: UIImage = .audioPlayerLock
        public lazy var stopRecordingIcon: UIImage = .audioPlayerStop
        public lazy var sendVoiceIcon: UIImage = .audioPlayerSendLarge
        public lazy var durationFormatter: TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .background,
            dividerColor: UIColor = .border,
            durationLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                             font: Fonts.regular.withSize(16)),
            slideToCancelTextStyleLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                           font: Fonts.regular.withSize(16)),
            slideToCancelText: String = L10n.Recorder.slideToCancel,
            cancelLabelAppearance: LabelAppearance = .init(foregroundColor: .stateWarning,
                                                           font: Fonts.regular.withSize(16)),
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
