//
//  ChannelInfoViewController+VideoAttachmentCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController.VideoAttachmentCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var videoDurationIcon: UIImage? = nil
        public var durationLabelAppearance: LabelAppearance = .init(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12),
            backgroundColor: .overlayBackground2
        )
        public var durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        
        public init(
            videoDurationIcon: UIImage? = nil,
            durationLabelAppearance: LabelAppearance = .init(
                foregroundColor: .onPrimary,
                font: Fonts.regular.withSize(12),
                backgroundColor: .overlayBackground2
            ),
            durationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        ) {
            self.videoDurationIcon = videoDurationIcon
            self.durationLabelAppearance = durationLabelAppearance
            self.durationFormatter = durationFormatter
        }
    }
}
