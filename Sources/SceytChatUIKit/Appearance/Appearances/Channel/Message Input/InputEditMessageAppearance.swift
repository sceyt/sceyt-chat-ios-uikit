//
//  InputEditMessageAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

public class InputEditMessageAppearance: AppearanceProviding {

    public var appearance: InputEditMessageAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: InputEditMessageAppearance?
    
    public static var appearance = InputEditMessageAppearance(
        backgroundColor: .surface1,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(13)
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
        editIcon: nil,
        attachmentDurationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        attachmentIconProvider: SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
        attachmentNameFormatter: SceytChatUIKit.shared.formatters.attachmentNameFormatter,
        mentionUserNameFormatter: SceytChatUIKit.shared.formatters.mentionUserNameFormatter,
        editMessageBodyFormatter: SceytChatUIKit.shared.formatters.editMessageBodyFormatter
    )
    
    @Trackable<InputEditMessageAppearance, UIColor>
    public var backgroundColor: UIColor
    
    @Trackable<InputEditMessageAppearance, LabelAppearance>
    public var titleLabelAppearance: LabelAppearance
    
    @Trackable<InputEditMessageAppearance, LabelAppearance>
    public var bodyLabelAppearance: LabelAppearance
    
    @Trackable<InputEditMessageAppearance, LabelAppearance>
    public var mentionLabelAppearance: LabelAppearance
    
    @Trackable<InputEditMessageAppearance, LabelAppearance>
    public var attachmentDurationLabelAppearance: LabelAppearance
    
    @Trackable<InputEditMessageAppearance, UIImage?>
    public var editIcon: UIImage?
    
    @Trackable<InputEditMessageAppearance, any TimeIntervalFormatting>
    public var attachmentDurationFormatter: any TimeIntervalFormatting
    
    @Trackable<InputEditMessageAppearance, any AttachmentIconProviding>
    public var attachmentIconProvider: any AttachmentIconProviding
    
    @Trackable<InputEditMessageAppearance, any AttachmentFormatting>
    public var attachmentNameFormatter: any AttachmentFormatting
    
    @Trackable<InputEditMessageAppearance, any UserFormatting>
    public var mentionUserNameFormatter: any UserFormatting
    
    @Trackable<InputEditMessageAppearance, any EditMessageBodyFormatting>
    public var editMessageBodyFormatter: any EditMessageBodyFormatting
    
    public init(
        backgroundColor: UIColor,
        titleLabelAppearance: LabelAppearance,
        bodyLabelAppearance: LabelAppearance,
        mentionLabelAppearance: LabelAppearance,
        attachmentDurationLabelAppearance: LabelAppearance,
        editIcon: UIImage?,
        attachmentDurationFormatter: any TimeIntervalFormatting,
        attachmentIconProvider: any AttachmentIconProviding,
        attachmentNameFormatter: any AttachmentFormatting,
        mentionUserNameFormatter: any UserFormatting,
        editMessageBodyFormatter: any EditMessageBodyFormatting
    ) {
        self._backgroundColor = Trackable(value: backgroundColor)
        self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
        self._bodyLabelAppearance = Trackable(value: bodyLabelAppearance)
        self._mentionLabelAppearance = Trackable(value: mentionLabelAppearance)
        self._attachmentDurationLabelAppearance = Trackable(value: attachmentDurationLabelAppearance)
        self._editIcon = Trackable(value: editIcon)
        self._attachmentDurationFormatter = Trackable(value: attachmentDurationFormatter)
        self._attachmentIconProvider = Trackable(value: attachmentIconProvider)
        self._attachmentNameFormatter = Trackable(value: attachmentNameFormatter)
        self._mentionUserNameFormatter = Trackable(value: mentionUserNameFormatter)
        self._editMessageBodyFormatter = Trackable(value: editMessageBodyFormatter)
    }
    
    public init(
        reference: InputEditMessageAppearance,
        backgroundColor: UIColor? = nil,
        titleLabelAppearance: LabelAppearance? = nil,
        bodyLabelAppearance: LabelAppearance? = nil,
        mentionLabelAppearance: LabelAppearance? = nil,
        attachmentDurationLabelAppearance: LabelAppearance? = nil,
        editIcon: UIImage? = nil,
        attachmentDurationFormatter: (any TimeIntervalFormatting)? = nil,
        attachmentIconProvider: (any AttachmentIconProviding)? = nil,
        attachmentNameFormatter: (any AttachmentFormatting)? = nil,
        mentionUserNameFormatter: (any UserFormatting)? = nil,
        editMessageBodyFormatter: (any EditMessageBodyFormatting)? = nil
    ) {
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
        self._bodyLabelAppearance = Trackable(reference: reference, referencePath: \.bodyLabelAppearance)
        self._mentionLabelAppearance = Trackable(reference: reference, referencePath: \.mentionLabelAppearance)
        self._attachmentDurationLabelAppearance = Trackable(reference: reference, referencePath: \.attachmentDurationLabelAppearance)
        self._editIcon = Trackable(reference: reference, referencePath: \.editIcon)
        self._attachmentDurationFormatter = Trackable(reference: reference, referencePath: \.attachmentDurationFormatter)
        self._attachmentIconProvider = Trackable(reference: reference, referencePath: \.attachmentIconProvider)
        self._attachmentNameFormatter = Trackable(reference: reference, referencePath: \.attachmentNameFormatter)
        self._mentionUserNameFormatter = Trackable(reference: reference, referencePath: \.mentionUserNameFormatter)
        self._editMessageBodyFormatter = Trackable(reference: reference, referencePath: \.editMessageBodyFormatter)
        
        if let backgroundColor { self.backgroundColor = backgroundColor }
        if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
        if let bodyLabelAppearance { self.bodyLabelAppearance = bodyLabelAppearance }
        if let mentionLabelAppearance { self.mentionLabelAppearance = mentionLabelAppearance }
        if let attachmentDurationLabelAppearance { self.attachmentDurationLabelAppearance = attachmentDurationLabelAppearance }
        if let editIcon { self.editIcon = editIcon }
        if let attachmentDurationFormatter { self.attachmentDurationFormatter = attachmentDurationFormatter }
        if let attachmentIconProvider { self.attachmentIconProvider = attachmentIconProvider }
        if let attachmentNameFormatter { self.attachmentNameFormatter = attachmentNameFormatter }
        if let mentionUserNameFormatter { self.mentionUserNameFormatter = mentionUserNameFormatter }
        if let editMessageBodyFormatter { self.editMessageBodyFormatter = editMessageBodyFormatter }
    }
}
