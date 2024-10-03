//
//  InputEditMessageAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

public struct InputEditMessageAppearance {
    public var backgroundColor: UIColor = .surface1
    public var titleLabelAppearance: LabelAppearance = .init(
        foregroundColor: .accent,
        font: Fonts.semiBold.withSize(13)
    )
    public var bodyTextStyle: LabelAppearance = .init(
        foregroundColor: .secondaryText,
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
    public var editIcon: UIImage? = nil
    public var attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
    public var attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
    public var attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter
    
    // Initializer with default values
    public init(
        backgroundColor: UIColor = .surface1,
        titleLabelAppearance: LabelAppearance = .init(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(13)
        ),
        bodyTextStyle: LabelAppearance = .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        mentionLabelAppearance: LabelAppearance = .init(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(13)
        ),
        attachmentDurationLabelAppearance: LabelAppearance = .init(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(13)
        ),
        editIcon: UIImage? = nil,
        attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
        attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter
    ) {
        self.backgroundColor = backgroundColor
        self.titleLabelAppearance = titleLabelAppearance
        self.bodyTextStyle = bodyTextStyle
        self.mentionLabelAppearance = mentionLabelAppearance
        self.attachmentDurationLabelAppearance = attachmentDurationLabelAppearance
        self.editIcon = editIcon
        self.attachmentDurationFormatter = attachmentDurationFormatter
        self.attachmentIconProvider = attachmentIconProvider
        self.attachmentNameFormatter = attachmentNameFormatter
    }
}
