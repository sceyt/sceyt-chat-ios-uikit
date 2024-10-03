//
//  ReplyMessageAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 28.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public struct ReplyMessageAppearance {
    
    public var titleLabelAppearance: LabelAppearance = .init(
        foregroundColor: .accent,
        font: Fonts.semiBold.withSize(13)
    )
    public var subtitleLabelAppearance: LabelAppearance = .init(
        foregroundColor: .primaryText,
        font: Fonts.regular.withSize(13)
    )
    public var mentionLabelAppearance: LabelAppearance = .init(
        foregroundColor: .accent,
        font: Fonts.regular.withSize(13)
    )
    public var attachmentDurationLabelAppearance: LabelAppearance = .init(
        foregroundColor: .accent,
        font: Fonts.regular.withSize(13)
    )
    public var deletedLabelAppearance: LabelAppearance = .init(
        foregroundColor: .accent,
        font: Fonts.regular.with(traits: .traitItalic).withSize(13)
    )
    public var borderColor: UIColor = .accent
    public var attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
    public var attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
    public var attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter
    public var senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
    
    // Initializer with default values
    public init(
        titleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(13)
        ),
        subtitleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(14)
        ),
        mentionLabelAppearance: LabelAppearance = .init(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(13)
        ),
        attachmentDurationLabelAppearance: LabelAppearance = .init(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(14)
        ),
        borderColor: UIColor = .accent,
        attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
        attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter,
        senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
    ) {
        self.titleLabelAppearance = titleLabelAppearance
        self.subtitleLabelAppearance = subtitleLabelAppearance
        self.mentionLabelAppearance = mentionLabelAppearance
        self.attachmentDurationLabelAppearance = attachmentDurationLabelAppearance
        self.borderColor = borderColor
        self.attachmentDurationFormatter = attachmentDurationFormatter
        self.attachmentIconProvider = attachmentIconProvider
        self.attachmentNameFormatter = attachmentNameFormatter
        self.senderNameFormatter = senderNameFormatter
    }
}
