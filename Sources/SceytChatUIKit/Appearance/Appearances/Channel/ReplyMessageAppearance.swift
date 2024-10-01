//
//  ReplyMessageAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 28.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//


import UIKit

public class ReplyMessageAppearance {
    
    public lazy var titleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                  font: Fonts.semiBold.withSize(13))
    public lazy var subtitleLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                       font: Fonts.regular.withSize(13))
    public lazy var mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                     font: Fonts.regular.withSize(13))
    public lazy var attachmentDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                               font: Fonts.regular.withSize(13))
    public lazy var deletedLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                    font: Fonts.regular.with(traits: .traitItalic).withSize(13))
    public lazy var borderColor: UIColor = .accent
    public lazy var attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
    public lazy var attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
    public lazy var attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter
    public lazy var senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
    
    // Initializer with default values
    public init(
        titleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                      font: Fonts.semiBold.withSize(13)),
        subtitleLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                           font: Fonts.regular.withSize(14)),
        mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                        font: Fonts.regular.withSize(13)),
        attachmentDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                   font: Fonts.regular.withSize(14)),
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
