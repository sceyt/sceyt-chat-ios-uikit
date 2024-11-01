//
//  InputReplyMessageAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

public class InputReplyMessageAppearance: AppearanceProviding {
    
    public var appearance: InputReplyMessageAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: InputReplyMessageAppearance?
    
    public static var appearance = InputReplyMessageAppearance(
        backgroundColor: .surface1,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(13)
        ),
        senderNameLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.bold.withSize(13)
        ),
        bodyLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        mentionLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(13)
        ),
        attachmentDurationLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(13)
        ),
        replyIcon: nil,
        attachmentDurationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        attachmentIconProvider: SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
        attachmentNameFormatter: SceytChatUIKit.shared.formatters.attachmentNameFormatter,
        senderNameFormatter: SceytChatUIKit.shared.formatters.userNameFormatter,
        mentionUserNameFormatter: SceytChatUIKit.shared.formatters.mentionUserNameFormatter,
        replyMessageBodyFormatter: SceytChatUIKit.shared.formatters.replyMessageBodyFormatter
    )
    
    @Trackable<InputReplyMessageAppearance, UIColor>
    public var backgroundColor: UIColor
    
    @Trackable<InputReplyMessageAppearance, LabelAppearance>
    public var titleLabelAppearance: LabelAppearance
    
    @Trackable<InputReplyMessageAppearance, LabelAppearance>
    public var senderNameLabelAppearance: LabelAppearance
    
    @Trackable<InputReplyMessageAppearance, LabelAppearance>
    public var bodyLabelAppearance: LabelAppearance
    
    @Trackable<InputReplyMessageAppearance, LabelAppearance>
    public var mentionLabelAppearance: LabelAppearance
    
    @Trackable<InputReplyMessageAppearance, LabelAppearance>
    public var attachmentDurationLabelAppearance: LabelAppearance
    
    @Trackable<InputReplyMessageAppearance, UIImage?>
    public var replyIcon: UIImage?
    
    @Trackable<InputReplyMessageAppearance, any TimeIntervalFormatting>
    public var attachmentDurationFormatter: any TimeIntervalFormatting
    
    @Trackable<InputReplyMessageAppearance, any AttachmentIconProviding>
    public var attachmentIconProvider: any AttachmentIconProviding
    
    @Trackable<InputReplyMessageAppearance, any AttachmentFormatting>
    public var attachmentNameFormatter: any AttachmentFormatting
    
    @Trackable<InputReplyMessageAppearance, any UserFormatting>
    public var senderNameFormatter: any UserFormatting
    
    @Trackable<InputReplyMessageAppearance, any UserFormatting>
    public var mentionUserNameFormatter: any UserFormatting
    
    @Trackable<InputReplyMessageAppearance, any ReplyMessageBodyFormatting>
    public var replyMessageBodyFormatter: any ReplyMessageBodyFormatting
    
    public init(
        backgroundColor: UIColor,
        titleLabelAppearance: LabelAppearance,
        senderNameLabelAppearance: LabelAppearance,
        bodyLabelAppearance: LabelAppearance,
        mentionLabelAppearance: LabelAppearance,
        attachmentDurationLabelAppearance: LabelAppearance,
        replyIcon: UIImage?,
        attachmentDurationFormatter: any TimeIntervalFormatting,
        attachmentIconProvider: any AttachmentIconProviding,
        attachmentNameFormatter: any AttachmentFormatting,
        senderNameFormatter: any UserFormatting,
        mentionUserNameFormatter: any UserFormatting,
        replyMessageBodyFormatter: any ReplyMessageBodyFormatting
    ) {
        self._backgroundColor = Trackable(value: backgroundColor)
        self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
        self._senderNameLabelAppearance = Trackable(value: senderNameLabelAppearance)
        self._bodyLabelAppearance = Trackable(value: bodyLabelAppearance)
        self._mentionLabelAppearance = Trackable(value: mentionLabelAppearance)
        self._attachmentDurationLabelAppearance = Trackable(value: attachmentDurationLabelAppearance)
        self._replyIcon = Trackable(value: replyIcon)
        self._attachmentDurationFormatter = Trackable(value: attachmentDurationFormatter)
        self._attachmentIconProvider = Trackable(value: attachmentIconProvider)
        self._attachmentNameFormatter = Trackable(value: attachmentNameFormatter)
        self._senderNameFormatter = Trackable(value: senderNameFormatter)
        self._mentionUserNameFormatter = Trackable(value: mentionUserNameFormatter)
        self._replyMessageBodyFormatter = Trackable(value: replyMessageBodyFormatter)
    }
    
    public init(
        reference: InputReplyMessageAppearance,
        backgroundColor: UIColor? = nil,
        titleLabelAppearance: LabelAppearance? = nil,
        senderNameLabelAppearance: LabelAppearance? = nil,
        bodyLabelAppearance: LabelAppearance? = nil,
        mentionLabelAppearance: LabelAppearance? = nil,
        attachmentDurationLabelAppearance: LabelAppearance? = nil,
        replyIcon: UIImage? = nil,
        attachmentDurationFormatter: (any TimeIntervalFormatting)? = nil,
        attachmentIconProvider: (any AttachmentIconProviding)? = nil,
        attachmentNameFormatter: (any AttachmentFormatting)? = nil,
        senderNameFormatter: (any UserFormatting)? = nil,
        mentionUserNameFormatter: (any UserFormatting)? = nil,
        replyMessageBodyFormatter: (any ReplyMessageBodyFormatting)? = nil
    ) {
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
        self._senderNameLabelAppearance = Trackable(reference: reference, referencePath: \.senderNameLabelAppearance)
        self._bodyLabelAppearance = Trackable(reference: reference, referencePath: \.bodyLabelAppearance)
        self._mentionLabelAppearance = Trackable(reference: reference, referencePath: \.mentionLabelAppearance)
        self._attachmentDurationLabelAppearance = Trackable(reference: reference, referencePath: \.attachmentDurationLabelAppearance)
        self._replyIcon = Trackable(reference: reference, referencePath: \.replyIcon)
        self._attachmentDurationFormatter = Trackable(reference: reference, referencePath: \.attachmentDurationFormatter)
        self._attachmentIconProvider = Trackable(reference: reference, referencePath: \.attachmentIconProvider)
        self._attachmentNameFormatter = Trackable(reference: reference, referencePath: \.attachmentNameFormatter)
        self._senderNameFormatter = Trackable(reference: reference, referencePath: \.senderNameFormatter)
        self._mentionUserNameFormatter = Trackable(reference: reference, referencePath: \.mentionUserNameFormatter)
        self._replyMessageBodyFormatter = Trackable(reference: reference, referencePath: \.replyMessageBodyFormatter)
        
        if let backgroundColor { self.backgroundColor = backgroundColor }
        if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
        if let senderNameLabelAppearance { self.senderNameLabelAppearance = senderNameLabelAppearance }
        if let bodyLabelAppearance { self.bodyLabelAppearance = bodyLabelAppearance }
        if let mentionLabelAppearance { self.mentionLabelAppearance = mentionLabelAppearance }
        if let attachmentDurationLabelAppearance { self.attachmentDurationLabelAppearance = attachmentDurationLabelAppearance }
        if let replyIcon { self.replyIcon = replyIcon }
        if let attachmentDurationFormatter { self.attachmentDurationFormatter = attachmentDurationFormatter }
        if let attachmentIconProvider { self.attachmentIconProvider = attachmentIconProvider }
        if let attachmentNameFormatter { self.attachmentNameFormatter = attachmentNameFormatter }
        if let senderNameFormatter { self.senderNameFormatter = senderNameFormatter }
        if let mentionUserNameFormatter { self.mentionUserNameFormatter = mentionUserNameFormatter }
        if let replyMessageBodyFormatter { self.replyMessageBodyFormatter = replyMessageBodyFormatter }
    }
}
