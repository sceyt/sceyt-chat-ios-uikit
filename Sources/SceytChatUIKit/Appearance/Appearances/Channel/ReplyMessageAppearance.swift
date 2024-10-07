//
//  ReplyMessageAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 28.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public class ReplyMessageAppearance: AppearanceProviding {
    public var appearance: ReplyMessageAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: ReplyMessageAppearance?
    
    public static var appearance = ReplyMessageAppearance(
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(13)
        ),
        subtitleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(14)
        ),
        mentionLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(13)
        ),
        attachmentDurationLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(14)
        ),
        deletedLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.with(traits: .traitItalic).withSize(13)
        ),
        borderColor: .accent,
        attachmentDurationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        attachmentIconProvider: SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
        attachmentNameFormatter: SceytChatUIKit.shared.formatters.attachmentNameFormatter,
        senderNameFormatter: SceytChatUIKit.shared.formatters.userNameFormatter
    )
    
    @Trackable<ReplyMessageAppearance, LabelAppearance>
    public var titleLabelAppearance: LabelAppearance
    
    @Trackable<ReplyMessageAppearance, LabelAppearance>
    public var subtitleLabelAppearance: LabelAppearance
    
    @Trackable<ReplyMessageAppearance, LabelAppearance>
    public var mentionLabelAppearance: LabelAppearance
    
    @Trackable<ReplyMessageAppearance, LabelAppearance>
    public var attachmentDurationLabelAppearance: LabelAppearance
    
    @Trackable<ReplyMessageAppearance, LabelAppearance>
    public var deletedLabelAppearance: LabelAppearance
    
    @Trackable<ReplyMessageAppearance, UIColor>
    public var borderColor: UIColor
    
    @Trackable<ReplyMessageAppearance, any TimeIntervalFormatting>
    public var attachmentDurationFormatter: any TimeIntervalFormatting
    
    @Trackable<ReplyMessageAppearance, any AttachmentIconProviding>
    public var attachmentIconProvider: any AttachmentIconProviding
    
    @Trackable<ReplyMessageAppearance, any AttachmentFormatting>
    public var attachmentNameFormatter: any AttachmentFormatting
    
    @Trackable<ReplyMessageAppearance, any UserFormatting>
    public var senderNameFormatter: any UserFormatting
    
    // Initializer with all parameters
    public init(
        titleLabelAppearance: LabelAppearance,
        subtitleLabelAppearance: LabelAppearance,
        mentionLabelAppearance: LabelAppearance,
        attachmentDurationLabelAppearance: LabelAppearance,
        deletedLabelAppearance: LabelAppearance,
        borderColor: UIColor,
        attachmentDurationFormatter: any TimeIntervalFormatting,
        attachmentIconProvider: any AttachmentIconProviding,
        attachmentNameFormatter: any AttachmentFormatting,
        senderNameFormatter: any UserFormatting
    ) {
        self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
        self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
        self._mentionLabelAppearance = Trackable(value: mentionLabelAppearance)
        self._attachmentDurationLabelAppearance = Trackable(value: attachmentDurationLabelAppearance)
        self._deletedLabelAppearance = Trackable(value: deletedLabelAppearance)
        self._borderColor = Trackable(value: borderColor)
        self._attachmentDurationFormatter = Trackable(value: attachmentDurationFormatter)
        self._attachmentIconProvider = Trackable(value: attachmentIconProvider)
        self._attachmentNameFormatter = Trackable(value: attachmentNameFormatter)
        self._senderNameFormatter = Trackable(value: senderNameFormatter)
    }
    
    // Initializer with optional parameters
    public init(
        reference: ReplyMessageAppearance,
        titleLabelAppearance: LabelAppearance? = nil,
        subtitleLabelAppearance: LabelAppearance? = nil,
        mentionLabelAppearance: LabelAppearance? = nil,
        attachmentDurationLabelAppearance: LabelAppearance? = nil,
        deletedLabelAppearance: LabelAppearance? = nil,
        borderColor: UIColor? = nil,
        attachmentDurationFormatter: (any TimeIntervalFormatting)? = nil,
        attachmentIconProvider: (any AttachmentIconProviding)? = nil,
        attachmentNameFormatter: (any AttachmentFormatting)? = nil,
        senderNameFormatter: (any UserFormatting)? = nil
    ) {
        self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
        self._subtitleLabelAppearance = Trackable(reference: reference, referencePath: \.subtitleLabelAppearance)
        self._mentionLabelAppearance = Trackable(reference: reference, referencePath: \.mentionLabelAppearance)
        self._attachmentDurationLabelAppearance = Trackable(reference: reference, referencePath: \.attachmentDurationLabelAppearance)
        self._deletedLabelAppearance = Trackable(reference: reference, referencePath: \.deletedLabelAppearance)
        self._borderColor = Trackable(reference: reference, referencePath: \.borderColor)
        self._attachmentDurationFormatter = Trackable(reference: reference, referencePath: \.attachmentDurationFormatter)
        self._attachmentIconProvider = Trackable(reference: reference, referencePath: \.attachmentIconProvider)
        self._attachmentNameFormatter = Trackable(reference: reference, referencePath: \.attachmentNameFormatter)
        self._senderNameFormatter = Trackable(reference: reference, referencePath: \.senderNameFormatter)
        
        if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
        if let subtitleLabelAppearance { self.subtitleLabelAppearance = subtitleLabelAppearance }
        if let mentionLabelAppearance { self.mentionLabelAppearance = mentionLabelAppearance }
        if let attachmentDurationLabelAppearance { self.attachmentDurationLabelAppearance = attachmentDurationLabelAppearance }
        if let deletedLabelAppearance { self.deletedLabelAppearance = deletedLabelAppearance }
        if let borderColor { self.borderColor = borderColor }
        if let attachmentDurationFormatter { self.attachmentDurationFormatter = attachmentDurationFormatter }
        if let attachmentIconProvider { self.attachmentIconProvider = attachmentIconProvider }
        if let attachmentNameFormatter { self.attachmentNameFormatter = attachmentNameFormatter }
        if let senderNameFormatter { self.senderNameFormatter = senderNameFormatter }
    }
}
