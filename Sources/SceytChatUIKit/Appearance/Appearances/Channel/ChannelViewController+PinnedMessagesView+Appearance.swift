//
//  ChannelViewController+PinnedMessagesView+Appearance.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController.PinnedMessagesView: AppearanceProviding {
    public static var appearance = Appearance(
        backgroundColor: .surface1,
        separatorColor: .border,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(13)
        ),
        messageLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(13)
        ),
        mentionLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(13)
        ),
        pinIcon: .pinnedMessagesIndicator,
        pinIconTintColor: .accent,
        indicatorActiveColor: .accent,
        indicatorInactiveColor: .border,
        deletedStateText: L10n.Message.deleted,
        pinnedMessageBodyFormatter: SceytChatUIKit.shared.formatters.pinnedMessageBodyFormatter,
        attachmentNameFormatter: SceytChatUIKit.shared.formatters.attachmentNameFormatter,
        attachmentDurationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        mentionUserNameFormatter: SceytChatUIKit.shared.formatters.mentionUserNameFormatter
    )

    public struct Appearance {

        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor

        @Trackable<Appearance, UIColor>
        public var separatorColor: UIColor

        @Trackable<Appearance, LabelAppearance>
        public var titleLabelAppearance: LabelAppearance

        @Trackable<Appearance, LabelAppearance>
        public var messageLabelAppearance: LabelAppearance

        @Trackable<Appearance, LabelAppearance>
        public var mentionLabelAppearance: LabelAppearance

        @Trackable<Appearance, UIImage>
        public var pinIcon: UIImage

        @Trackable<Appearance, UIColor>
        public var pinIconTintColor: UIColor

        /// The segment for the pin currently on screen.
        @Trackable<Appearance, UIColor>
        public var indicatorActiveColor: UIColor

        @Trackable<Appearance, UIColor>
        public var indicatorInactiveColor: UIColor

        @Trackable<Appearance, String>
        public var deletedStateText: String

        @Trackable<Appearance, any PinnedMessageBodyFormatting>
        public var pinnedMessageBodyFormatter: any PinnedMessageBodyFormatting

        @Trackable<Appearance, any AttachmentFormatting>
        public var attachmentNameFormatter: any AttachmentFormatting

        /// Renders a voice pin's length, shown next to its name — "Voice: 00:56".
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var attachmentDurationFormatter: any TimeIntervalFormatting

        @Trackable<Appearance, any UserFormatting>
        public var mentionUserNameFormatter: any UserFormatting

        public init(
            backgroundColor: UIColor,
            separatorColor: UIColor,
            titleLabelAppearance: LabelAppearance,
            messageLabelAppearance: LabelAppearance,
            mentionLabelAppearance: LabelAppearance,
            pinIcon: UIImage,
            pinIconTintColor: UIColor,
            indicatorActiveColor: UIColor,
            indicatorInactiveColor: UIColor,
            deletedStateText: String,
            pinnedMessageBodyFormatter: any PinnedMessageBodyFormatting,
            attachmentNameFormatter: any AttachmentFormatting,
            attachmentDurationFormatter: any TimeIntervalFormatting,
            mentionUserNameFormatter: any UserFormatting
        ) {
            self._backgroundColor = Trackable(value: backgroundColor)
            self._separatorColor = Trackable(value: separatorColor)
            self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
            self._messageLabelAppearance = Trackable(value: messageLabelAppearance)
            self._mentionLabelAppearance = Trackable(value: mentionLabelAppearance)
            self._pinIcon = Trackable(value: pinIcon)
            self._pinIconTintColor = Trackable(value: pinIconTintColor)
            self._indicatorActiveColor = Trackable(value: indicatorActiveColor)
            self._indicatorInactiveColor = Trackable(value: indicatorInactiveColor)
            self._deletedStateText = Trackable(value: deletedStateText)
            self._pinnedMessageBodyFormatter = Trackable(value: pinnedMessageBodyFormatter)
            self._attachmentNameFormatter = Trackable(value: attachmentNameFormatter)
            self._attachmentDurationFormatter = Trackable(value: attachmentDurationFormatter)
            self._mentionUserNameFormatter = Trackable(value: mentionUserNameFormatter)
        }

        public init(
            reference: ChannelViewController.PinnedMessagesView.Appearance,
            backgroundColor: UIColor? = nil,
            separatorColor: UIColor? = nil,
            titleLabelAppearance: LabelAppearance? = nil,
            messageLabelAppearance: LabelAppearance? = nil,
            mentionLabelAppearance: LabelAppearance? = nil,
            pinIcon: UIImage? = nil,
            pinIconTintColor: UIColor? = nil,
            indicatorActiveColor: UIColor? = nil,
            indicatorInactiveColor: UIColor? = nil,
            deletedStateText: String? = nil,
            pinnedMessageBodyFormatter: (any PinnedMessageBodyFormatting)? = nil,
            attachmentNameFormatter: (any AttachmentFormatting)? = nil,
            attachmentDurationFormatter: (any TimeIntervalFormatting)? = nil,
            mentionUserNameFormatter: (any UserFormatting)? = nil
        ) {
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._separatorColor = Trackable(reference: reference, referencePath: \.separatorColor)
            self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
            self._messageLabelAppearance = Trackable(reference: reference, referencePath: \.messageLabelAppearance)
            self._mentionLabelAppearance = Trackable(reference: reference, referencePath: \.mentionLabelAppearance)
            self._pinIcon = Trackable(reference: reference, referencePath: \.pinIcon)
            self._pinIconTintColor = Trackable(reference: reference, referencePath: \.pinIconTintColor)
            self._indicatorActiveColor = Trackable(reference: reference, referencePath: \.indicatorActiveColor)
            self._indicatorInactiveColor = Trackable(reference: reference, referencePath: \.indicatorInactiveColor)
            self._deletedStateText = Trackable(reference: reference, referencePath: \.deletedStateText)
            self._pinnedMessageBodyFormatter = Trackable(reference: reference, referencePath: \.pinnedMessageBodyFormatter)
            self._attachmentNameFormatter = Trackable(reference: reference, referencePath: \.attachmentNameFormatter)
            self._attachmentDurationFormatter = Trackable(reference: reference, referencePath: \.attachmentDurationFormatter)
            self._mentionUserNameFormatter = Trackable(reference: reference, referencePath: \.mentionUserNameFormatter)

            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let separatorColor { self.separatorColor = separatorColor }
            if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
            if let messageLabelAppearance { self.messageLabelAppearance = messageLabelAppearance }
            if let mentionLabelAppearance { self.mentionLabelAppearance = mentionLabelAppearance }
            if let pinIcon { self.pinIcon = pinIcon }
            if let pinIconTintColor { self.pinIconTintColor = pinIconTintColor }
            if let indicatorActiveColor { self.indicatorActiveColor = indicatorActiveColor }
            if let indicatorInactiveColor { self.indicatorInactiveColor = indicatorInactiveColor }
            if let deletedStateText { self.deletedStateText = deletedStateText }
            if let pinnedMessageBodyFormatter { self.pinnedMessageBodyFormatter = pinnedMessageBodyFormatter }
            if let attachmentNameFormatter { self.attachmentNameFormatter = attachmentNameFormatter }
            if let attachmentDurationFormatter { self.attachmentDurationFormatter = attachmentDurationFormatter }
            if let mentionUserNameFormatter { self.mentionUserNameFormatter = mentionUserNameFormatter }
        }
    }
}
