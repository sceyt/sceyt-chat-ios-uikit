//
//  InputReplyMessageAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

public class InputReplyMessageAppearance {
    public lazy var backgroundColor: UIColor = .surface1
    public lazy var titleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                  font: Fonts.semiBold.withSize(13))
    public lazy var senderNameLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                       font: Fonts.bold.withSize(13))
    public lazy var bodyLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                 font: Fonts.regular.withSize(13))
    public lazy var attachmentDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                               font: Fonts.regular.withSize(13))
    public lazy var replyIcon: UIImage? = nil
    
    public lazy var attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
    public lazy var attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
    public lazy var attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter
    public lazy var senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
    
    // Initializer with default values
    public init(
        backgroundColor: UIColor = .surface1,
        titleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                      font: Fonts.semiBold.withSize(13)),
        senderNameLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                           font: Fonts.bold.withSize(13)),
        bodyLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                     font: Fonts.regular.withSize(13)),
        attachmentDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                   font: Fonts.regular.withSize(13)),
        replyIcon: UIImage? = nil,
        attachmentDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
        attachmentNameFormatter: any AttachmentFormatting = SceytChatUIKit.shared.formatters.attachmentNameFormatter,
        senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
    ) {
        self.backgroundColor = backgroundColor
        self.titleLabelAppearance = titleLabelAppearance
        self.senderNameLabelAppearance = senderNameLabelAppearance
        self.bodyLabelAppearance = bodyLabelAppearance
        self.attachmentDurationLabelAppearance = attachmentDurationLabelAppearance
        self.replyIcon = replyIcon
        self.attachmentDurationFormatter = attachmentDurationFormatter
        self.attachmentIconProvider = attachmentIconProvider
        self.attachmentNameFormatter = attachmentNameFormatter
        self.senderNameFormatter = senderNameFormatter
    }
}
