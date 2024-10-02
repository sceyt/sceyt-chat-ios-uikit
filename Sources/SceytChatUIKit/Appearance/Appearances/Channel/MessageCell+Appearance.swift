//
//  MessageCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 28.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        // Static properties
        public static var bubbleOutgoing: UIColor = DefaultColors.bubbleOutgoing
        public static var bubbleOutgoingSecondary: UIColor = DefaultColors.bubbleOutgoingSecondary
        public static var bubbleIncoming: UIColor = DefaultColors.bubbleIncoming
        public static var bubbleIncomingSecondary: UIColor = DefaultColors.bubbleIncomingSecondary
        public static var bubbleOutgoingHighlighted: UIColor = DefaultColors.bubbleOutgoingHighlighted
        public static var bubbleOutgoingHighlightedSecondary: UIColor = DefaultColors.bubbleOutgoingHighlightedSecondary
        public static var bubbleIncomingHighlighted: UIColor = DefaultColors.bubbleIncomingHighlighted
        public static var bubbleIncomingHighlightedSecondary: UIColor = DefaultColors.bubbleIncomingHighlightedSecondary
        
        // Colors
        public lazy var backgroundColor: UIColor = .clear
        public lazy var incomingBubbleColor: UIColor = Self.bubbleIncoming
        public lazy var outgoingBubbleColor: UIColor = Self.bubbleOutgoing
        public lazy var incomingReplyBackgroundColor: UIColor = Self.bubbleIncomingSecondary
        public lazy var outgoingReplyBackgroundColor: UIColor = Self.bubbleOutgoingSecondary
        public lazy var incomingLinkPreviewBackgroundColor: UIColor = Self.bubbleIncomingSecondary
        public lazy var outgoingLinkPreviewBackgroundColor: UIColor = Self.bubbleOutgoingSecondary
        public lazy var incomingHighlightedBubbleColor: UIColor = Self.bubbleIncomingHighlighted
        public lazy var outgoingHighlightedBubbleColor: UIColor = Self.bubbleOutgoingHighlighted
        public lazy var incomingHighlightedOverlayColor: UIColor = Self.bubbleIncomingHighlightedSecondary
        public lazy var outgoingHighlightedOverlayColor: UIColor = Self.bubbleOutgoingHighlightedSecondary
        public lazy var incomingHighlightedSearchResultColor: UIColor = Self.bubbleIncomingHighlighted
        public lazy var outgoingHighlightedSearchResultColor: UIColor = Self.bubbleOutgoingHighlighted
        public lazy var incomingHighlightedOverlaySearchResultColor: UIColor = Self.bubbleIncomingHighlightedSecondary
        public lazy var outgoingHighlightedOverlaySearchResultColor: UIColor = Self.bubbleOutgoingHighlightedSecondary
        public lazy var overlayColor: UIColor = .overlayBackground2
        public lazy var onOverlayColor: UIColor = .onPrimary
        public lazy var reactionsContainerBackgroundColor: UIColor = .backgroundSections
        public lazy var threadReplyArrowStrokeColor: UIColor = .border
        
        // Label Appearances
        public lazy var senderNameLabelAppearance: LabelAppearance = .init(foregroundColor: nil, // Will use randomized color from initials colors
                                                                           font: Fonts.semiBold.withSize(14))
        public lazy var bodyLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                     font: Fonts.regular.withSize(16))
        public lazy var mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                        font: Fonts.regular.withSize(16))
        public lazy var deletedMessageLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                               font: Fonts.regular.with(traits: .traitItalic).withSize(16))
        public lazy var messageDateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                            font: Fonts.regular.withSize(12))
        public lazy var messageStateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                             font: Fonts.regular.with(traits: .traitItalic).withSize(12))
        public lazy var linkLabelAppearance: LabelAppearance = .init(foregroundColor: .systemBlue,
                                                                     font: Fonts.regular.withSize(16))
        public lazy var linkPreviewAppearance: LinkPreviewAppearance = .init(
            titleLabelAppearance: .init(foregroundColor: .primaryText,
                                        font: Fonts.semiBold.withSize(14)),
            descriptionLabelAppearance: .init(foregroundColor: .secondaryText,
                                              font: Fonts.regular.withSize(13)),
            highlightedLinkBackgroundColor: .footnoteText
        )
        public lazy var videoDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary,
                                                                              font: Fonts.regular.withSize(12))
        public lazy var threadReplyCountLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                                 font: Fonts.semiBold.withSize(12))
        public lazy var forwardedTitleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                               font: Fonts.semiBold.withSize(13))
        public lazy var reactionCountLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                              font: Fonts.regular.withSize(13))
        public lazy var voiceSpeedLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                           font: Fonts.semiBold.withSize(12),
                                                                           backgroundColor: .background)
        public lazy var voiceDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .footnoteText,
                                                                              font: Fonts.regular.withSize(11))
        public lazy var attachmentFileNameLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
                                                                                   font: Fonts.semiBold.withSize(16))
        public lazy var attachmentFileSizeLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                                   font: Fonts.regular.withSize(12))
        
        // Icons
        public lazy var messageDeliveryStatusIcons: MessageDeliveryStatusIcons = .init()
        public lazy var viewCountIcon: UIImage = .eye
        public lazy var videoIcon: UIImage = .galleryVideoAsset
        public lazy var videoPlayIcon: UIImage = .videoPlay
        public lazy var swipeToReplyIcon: UIImage = .channelReply
        public lazy var forwardedIcon: UIImage = .forwardedMessage
        public lazy var voicePlayIcon: UIImage = .audioPlayerPlay
        public lazy var voicePauseIcon: UIImage = .audioPlayerPause
        
        // Other Appearances
        public lazy var unreadMessagesSeparatorAppearance: UnreadMessagesSeparatorView.Appearance = .init(backgroundColor: Appearance.bubbleIncoming)
        public lazy var replyMessageAppearance: ReplyMessageAppearance = .init()
        public lazy var checkboxAppearance: CheckBoxView.Appearance = CheckBoxView.appearance
        public lazy var voiceWaveformViewAppearance: AudioWaveformView.Appearance = AudioWaveformView.appearance
        public lazy var mediaLoaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
                                                                                       trackColor: .clear,
                                                                                       backgroundColor: .accent,
                                                                                       cancelIcon: nil,
                                                                                       uploadIcon: nil,
                                                                                       downloadIcon: nil)
        public lazy var overlayMediaLoaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
                                                                                              trackColor: .clear,
                                                                                              backgroundColor: .overlayBackground2,
                                                                                              cancelIcon: .attachmentTransferPause,
                                                                                              uploadIcon: .attachmentUpload,
                                                                                              downloadIcon: .attachmentDownload)
        
        // Other properties
        public lazy var editedStateText: String = L10n.Message.Info.edited
        public lazy var deletedStateText: String = L10n.Message.deleted
        public lazy var forwardedText: String = L10n.Message.Forward.title
        
        // Formatters and providers
        public lazy var attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
        public lazy var senderNameColorProvider: any UserColorProviding = SceytChatUIKit.shared.visualProviders.senderNameColorProvider
        public lazy var senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
        public lazy var voiceDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
        public lazy var attachmentFileSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.attachmentSizeFormatter
        public lazy var messageViewCountFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.messageViewCountFormatter
        public lazy var messageDateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.messageDateFormatter
        public lazy var mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.mentionUserNameFormatter
        public lazy var userDefaultAvatarProvider: any UserAvatarProviding = SceytChatUIKit.shared.visualProviders.userAvatarProvider
        
        public init(
            // Colors
            backgroundColor: UIColor = .clear,
            incomingBubbleColor: UIColor = Appearance.bubbleIncoming,
            outgoingBubbleColor: UIColor = Appearance.bubbleOutgoing,
            incomingReplyBackgroundColor: UIColor = Appearance.bubbleIncomingSecondary,
            outgoingReplyBackgroundColor: UIColor = Appearance.bubbleOutgoingSecondary,
            incomingLinkPreviewBackgroundColor: UIColor = Appearance.bubbleIncomingSecondary,
            outgoingLinkPreviewBackgroundColor: UIColor = Appearance.bubbleOutgoingSecondary,
            incomingHighlightedBubbleColor: UIColor = Appearance.bubbleIncomingHighlighted,
            outgoingHighlightedBubbleColor: UIColor = Appearance.bubbleOutgoingHighlighted,
            incomingHighlightedOverlayColor: UIColor = Appearance.bubbleIncomingHighlightedSecondary,
            outgoingHighlightedOverlayColor: UIColor = Appearance.bubbleOutgoingHighlightedSecondary,
            incomingHighlightedSearchResultColor: UIColor = Appearance.bubbleIncomingHighlighted,
            outgoingHighlightedSearchResultColor: UIColor = Appearance.bubbleOutgoingHighlighted,
            incomingHighlightedOverlaySearchResultColor: UIColor = Appearance.bubbleIncomingHighlightedSecondary,
            outgoingHighlightedOverlaySearchResultColor: UIColor = Appearance.bubbleOutgoingHighlightedSecondary,
            overlayColor: UIColor = .overlayBackground2,
            onOverlayColor: UIColor = .onPrimary,
            reactionsContainerBackgroundColor: UIColor = .backgroundSections,
            threadReplyArrowStrokeColor: UIColor = .border,
            
            // Label Appearances
            senderNameLabelAppearance: LabelAppearance = .init(foregroundColor: nil, font: Fonts.semiBold.withSize(14)),
            bodyLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.regular.withSize(16)),
            mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .accent, font: Fonts.regular.withSize(16)),
            deletedMessageLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.with(traits: .traitItalic).withSize(16)),
            messageDateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(12)),
            messageStateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.with(traits: .traitItalic).withSize(12)),
            linkLabelAppearance: LabelAppearance = .init(foregroundColor: .systemBlue, font: Fonts.regular.withSize(16)),
            linkPreviewAppearance: LinkPreviewAppearance = .init(
                titleLabelAppearance: .init(foregroundColor: .primaryText, font: Fonts.semiBold.withSize(14)),
                descriptionLabelAppearance: .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(13)),
                highlightedLinkBackgroundColor: .footnoteText,
                placeholderIcon: nil
            ),
            videoDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary, font: Fonts.regular.withSize(12)),
            threadReplyCountLabelAppearance: LabelAppearance = .init(foregroundColor: .accent, font: Fonts.semiBold.withSize(12)),
            forwardedTitleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent, font: Fonts.semiBold.withSize(13)),
            reactionCountLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.regular.withSize(13)),
            voiceSpeedLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.semiBold.withSize(12), backgroundColor: .background),
            voiceDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .footnoteText, font: Fonts.regular.withSize(11)),
            attachmentFileNameLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.semiBold.withSize(16)),
            attachmentFileSizeLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(12)),
            
            // Icons
            messageDeliveryStatusIcons: MessageDeliveryStatusIcons = .init(),
            viewCountIcon: UIImage = .eye,
            videoIcon: UIImage = .galleryVideoAsset,
            videoPlayIcon: UIImage = .videoPlay,
            swipeToReplyIcon: UIImage = .channelReply,
            forwardedIcon: UIImage = .forwardedMessage,
            voicePlayIcon: UIImage = .audioPlayerPlay,
            voicePauseIcon: UIImage = .audioPlayerPause,
            
            // Other Appearances
            unreadMessagesSeparatorAppearance: UnreadMessagesSeparatorView.Appearance = .init(backgroundColor: Appearance.bubbleIncoming),
            replyMessageAppearance: ReplyMessageAppearance = .init(),
            checkboxAppearance: CheckBoxView.Appearance = CheckBoxView.appearance,
            voiceWaveformViewAppearance: AudioWaveformView.Appearance = AudioWaveformView.appearance,
            mediaLoaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
                                                                           trackColor: .clear,
                                                                           backgroundColor: .accent,
                                                                           cancelIcon: nil,
                                                                           uploadIcon: nil,
                                                                           downloadIcon: nil),
            overlayMediaLoaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
                                                                                  trackColor: .clear,
                                                                                  backgroundColor: .overlayBackground2,
                                                                                  cancelIcon: .attachmentTransferPause,
                                                                                  uploadIcon: .attachmentUpload,
                                                                                  downloadIcon: .attachmentDownload),
            
            // Other properties
            editedStateText: String = L10n.Message.Info.edited,
            deletedStateText: String = L10n.Message.deleted,
            forwardedText: String = L10n.Message.Forward.title,
            
            // Formatters and providers
            attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
            senderNameColorProvider: any UserColorProviding = SceytChatUIKit.shared.visualProviders.senderNameColorProvider,
            senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter,
            voiceDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter,
            attachmentFileSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.attachmentSizeFormatter,
            messageViewCountFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.messageViewCountFormatter,
            messageDateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.messageDateFormatter,
            mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.mentionUserNameFormatter,
            userDefaultAvatarProvider: any UserAvatarProviding = SceytChatUIKit.shared.visualProviders.userAvatarProvider
        ) {
            // Colors
            self.backgroundColor = backgroundColor
            self.incomingBubbleColor = incomingBubbleColor
            self.outgoingBubbleColor = outgoingBubbleColor
            self.incomingReplyBackgroundColor = incomingReplyBackgroundColor
            self.outgoingReplyBackgroundColor = outgoingReplyBackgroundColor
            self.incomingLinkPreviewBackgroundColor = incomingLinkPreviewBackgroundColor
            self.outgoingLinkPreviewBackgroundColor = outgoingLinkPreviewBackgroundColor
            self.incomingHighlightedBubbleColor = incomingHighlightedBubbleColor
            self.outgoingHighlightedBubbleColor = outgoingHighlightedBubbleColor
            self.incomingHighlightedOverlayColor = incomingHighlightedOverlayColor
            self.outgoingHighlightedOverlayColor = outgoingHighlightedOverlayColor
            self.incomingHighlightedSearchResultColor = incomingHighlightedSearchResultColor
            self.outgoingHighlightedSearchResultColor = outgoingHighlightedSearchResultColor
            self.incomingHighlightedOverlaySearchResultColor = incomingHighlightedOverlaySearchResultColor
            self.outgoingHighlightedOverlaySearchResultColor = outgoingHighlightedOverlaySearchResultColor
            self.overlayColor = overlayColor
            self.onOverlayColor = onOverlayColor
            self.reactionsContainerBackgroundColor = reactionsContainerBackgroundColor
            self.threadReplyArrowStrokeColor = threadReplyArrowStrokeColor
            
            // Label Appearances
            self.senderNameLabelAppearance = senderNameLabelAppearance
            self.bodyLabelAppearance = bodyLabelAppearance
            self.mentionLabelAppearance = mentionLabelAppearance
            self.deletedMessageLabelAppearance = deletedMessageLabelAppearance
            self.messageDateLabelAppearance = messageDateLabelAppearance
            self.messageStateLabelAppearance = messageStateLabelAppearance
            self.linkLabelAppearance = linkLabelAppearance
            self.linkPreviewAppearance = linkPreviewAppearance
            self.videoDurationLabelAppearance = videoDurationLabelAppearance
            self.threadReplyCountLabelAppearance = threadReplyCountLabelAppearance
            self.forwardedTitleLabelAppearance = forwardedTitleLabelAppearance
            self.reactionCountLabelAppearance = reactionCountLabelAppearance
            self.voiceSpeedLabelAppearance = voiceSpeedLabelAppearance
            self.voiceDurationLabelAppearance = voiceDurationLabelAppearance
            self.attachmentFileNameLabelAppearance = attachmentFileNameLabelAppearance
            self.attachmentFileSizeLabelAppearance = attachmentFileSizeLabelAppearance
            
            // Icons
            self.messageDeliveryStatusIcons = messageDeliveryStatusIcons
            self.viewCountIcon = viewCountIcon
            self.videoIcon = videoIcon
            self.videoPlayIcon = videoPlayIcon
            self.swipeToReplyIcon = swipeToReplyIcon
            self.forwardedIcon = forwardedIcon
            self.voicePlayIcon = voicePlayIcon
            self.voicePauseIcon = voicePauseIcon
            
            // Other Appearances
            self.unreadMessagesSeparatorAppearance = unreadMessagesSeparatorAppearance
            self.replyMessageAppearance = replyMessageAppearance
            self.checkboxAppearance = checkboxAppearance
            self.voiceWaveformViewAppearance = voiceWaveformViewAppearance
            self.mediaLoaderAppearance = mediaLoaderAppearance
            self.overlayMediaLoaderAppearance = overlayMediaLoaderAppearance
            
            // Other properties
            self.editedStateText = editedStateText
            self.deletedStateText = deletedStateText
            self.forwardedText = forwardedText
            
            // Formatters and providers
            self.attachmentIconProvider = attachmentIconProvider
            self.senderNameColorProvider = senderNameColorProvider
            self.senderNameFormatter = senderNameFormatter
            self.voiceDurationFormatter = voiceDurationFormatter
            self.attachmentFileSizeFormatter = attachmentFileSizeFormatter
            self.messageViewCountFormatter = messageViewCountFormatter
            self.messageDateFormatter = messageDateFormatter
            self.mentionUserNameFormatter = mentionUserNameFormatter
            self.userDefaultAvatarProvider = userDefaultAvatarProvider
        }
    }
}


