////
////  MessageCell+Appearance.swift
////  SceytChatUIKit
////
////  Created by Arthur Avagyan on 28.09.24
////  Copyright © 2024 Sceyt LLC. All rights reserved.
////
//
//import UIKit
//
//extension MessageCell: AppearanceProviding {
//    public static var appearance = Appearance()
//    
//    public struct Appearance {
//        // Static properties
//        public static var bubbleOutgoing: UIColor = DefaultColors.bubbleOutgoing
//        public static var bubbleOutgoingSecondary: UIColor = DefaultColors.bubbleOutgoingSecondary
//        public static var bubbleIncoming: UIColor = DefaultColors.bubbleIncoming
//        public static var bubbleIncomingSecondary: UIColor = DefaultColors.bubbleIncomingSecondary
//        public static var bubbleOutgoingHighlighted: UIColor = DefaultColors.bubbleOutgoingHighlighted
//        public static var bubbleOutgoingHighlightedSecondary: UIColor = DefaultColors.bubbleOutgoingHighlightedSecondary
//        public static var bubbleIncomingHighlighted: UIColor = DefaultColors.bubbleIncomingHighlighted
//        public static var bubbleIncomingHighlightedSecondary: UIColor = DefaultColors.bubbleIncomingHighlightedSecondary
//        
//        // Colors
//        public var backgroundColor: UIColor = .clear
//        public var incomingBubbleColor: UIColor = Self.bubbleIncoming
//        public var outgoingBubbleColor: UIColor = Self.bubbleOutgoing
//        public var incomingReplyBackgroundColor: UIColor = Self.bubbleIncomingSecondary
//        public var outgoingReplyBackgroundColor: UIColor = Self.bubbleOutgoingSecondary
//        public var incomingLinkPreviewBackgroundColor: UIColor = Self.bubbleIncomingSecondary
//        public var outgoingLinkPreviewBackgroundColor: UIColor = Self.bubbleOutgoingSecondary
//        public var incomingHighlightedBubbleColor: UIColor = Self.bubbleIncomingHighlighted
//        public var outgoingHighlightedBubbleColor: UIColor = Self.bubbleOutgoingHighlighted
//        public var incomingHighlightedOverlayColor: UIColor = Self.bubbleIncomingHighlightedSecondary
//        public var outgoingHighlightedOverlayColor: UIColor = Self.bubbleOutgoingHighlightedSecondary
//        public var incomingHighlightedSearchResultColor: UIColor = Self.bubbleIncomingHighlighted
//        public var outgoingHighlightedSearchResultColor: UIColor = Self.bubbleOutgoingHighlighted
//        public var incomingHighlightedOverlaySearchResultColor: UIColor = Self.bubbleIncomingHighlightedSecondary
//        public var outgoingHighlightedOverlaySearchResultColor: UIColor = Self.bubbleOutgoingHighlightedSecondary
//        public var overlayColor: UIColor = .overlayBackground2
//        public var onOverlayColor: UIColor = .onPrimary
//        public var reactionsContainerBackgroundColor: UIColor = .backgroundSections
//        public var threadReplyArrowStrokeColor: UIColor = .border
//        
//        // Label Appearances
//        public var senderNameLabelAppearance: LabelAppearance = .init(foregroundColor: nil, // Will use randomized color from initials colors
//                                                                           font: Fonts.semiBold.withSize(14))
//        public var bodyLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
//                                                                     font: Fonts.regular.withSize(16))
//        public var mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
//                                                                        font: Fonts.regular.withSize(16))
//        public var deletedMessageLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
//                                                                               font: Fonts.regular.with(traits: .traitItalic).withSize(16))
//        public var messageDateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
//                                                                            font: Fonts.regular.withSize(12))
//        public var messageStateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
//                                                                             font: Fonts.regular.with(traits: .traitItalic).withSize(12))
//        public var linkLabelAppearance: LabelAppearance = .init(foregroundColor: .systemBlue,
//                                                                     font: Fonts.regular.withSize(16))
//        public var linkPreviewAppearance: LinkPreviewAppearance = .init(
//            titleLabelAppearance: .init(foregroundColor: .primaryText,
//                                        font: Fonts.semiBold.withSize(14)),
//            descriptionLabelAppearance: .init(foregroundColor: .secondaryText,
//                                              font: Fonts.regular.withSize(13)),
//            highlightedLinkBackgroundColor: .footnoteText
//        )
//        public var videoDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary,
//                                                                              font: Fonts.regular.withSize(12))
//        public var threadReplyCountLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
//                                                                                 font: Fonts.semiBold.withSize(12))
//        public var forwardedTitleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
//                                                                               font: Fonts.semiBold.withSize(13))
//        public var reactionCountLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
//                                                                              font: Fonts.regular.withSize(13))
//        public var voiceSpeedLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
//                                                                           font: Fonts.semiBold.withSize(12),
//                                                                           backgroundColor: .background)
//        public var voiceDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .footnoteText,
//                                                                              font: Fonts.regular.withSize(11))
//        public var attachmentFileNameLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText,
//                                                                                   font: Fonts.semiBold.withSize(16))
//        public var attachmentFileSizeLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
//                                                                                   font: Fonts.regular.withSize(12))
//        
//        // Icons
//        public var messageDeliveryStatusIcons: MessageDeliveryStatusIcons = .init()
//        public var viewCountIcon: UIImage = .eye
//        public var videoIcon: UIImage = .galleryVideoAsset
//        public var videoPlayIcon: UIImage = .videoPlay
//        public var swipeToReplyIcon: UIImage = .channelReply
//        public var forwardedIcon: UIImage = .forwardedMessage
//        public var voicePlayIcon: UIImage = .audioPlayerPlay
//        public var voicePauseIcon: UIImage = .audioPlayerPause
//        
//        // Other Appearances
//        public var unreadMessagesSeparatorAppearance: UnreadMessagesSeparatorView.Appearance = .init(backgroundColor: Appearance.bubbleIncoming)
//        public var replyMessageAppearance: ReplyMessageAppearance = .init()
//        public var checkboxAppearance: CheckBoxView.Appearance = CheckBoxView.appearance
//        public var voiceWaveformViewAppearance: AudioWaveformView.Appearance = AudioWaveformView.appearance
//        public var mediaLoaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
//                                                                                       trackColor: .clear,
//                                                                                       backgroundColor: .accent,
//                                                                                       cancelIcon: nil,
//                                                                                       uploadIcon: nil,
//                                                                                       downloadIcon: nil)
//        public var overlayMediaLoaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
//                                                                                              trackColor: .clear,
//                                                                                              backgroundColor: .overlayBackground2,
//                                                                                              cancelIcon: .attachmentTransferPause,
//                                                                                              uploadIcon: .attachmentUpload,
//                                                                                              downloadIcon: .attachmentDownload)
//        
//        // Other properties
//        public var editedStateText: String = L10n.Message.Info.edited
//        public var deletedStateText: String = L10n.Message.deleted
//        public var forwardedText: String = L10n.Message.Forward.title
//        
//        // Formatters and providers
//        public var attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider
//        public var senderNameColorProvider: any UserColorProviding = SceytChatUIKit.shared.visualProviders.senderNameColorProvider
//        public var senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter
//        public var voiceDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter
//        public var attachmentFileSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.attachmentSizeFormatter
//        public var messageViewCountFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.messageViewCountFormatter
//        public var messageDateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.messageDateFormatter
//        public var mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.mentionUserNameFormatter
//        public var userDefaultAvatarProvider: any UserAvatarProviding = SceytChatUIKit.shared.visualProviders.userAvatarProvider
//        
//        public init(
//            // Colors
//            backgroundColor: UIColor = .clear,
//            incomingBubbleColor: UIColor = Appearance.bubbleIncoming,
//            outgoingBubbleColor: UIColor = Appearance.bubbleOutgoing,
//            incomingReplyBackgroundColor: UIColor = Appearance.bubbleIncomingSecondary,
//            outgoingReplyBackgroundColor: UIColor = Appearance.bubbleOutgoingSecondary,
//            incomingLinkPreviewBackgroundColor: UIColor = Appearance.bubbleIncomingSecondary,
//            outgoingLinkPreviewBackgroundColor: UIColor = Appearance.bubbleOutgoingSecondary,
//            incomingHighlightedBubbleColor: UIColor = Appearance.bubbleIncomingHighlighted,
//            outgoingHighlightedBubbleColor: UIColor = Appearance.bubbleOutgoingHighlighted,
//            incomingHighlightedOverlayColor: UIColor = Appearance.bubbleIncomingHighlightedSecondary,
//            outgoingHighlightedOverlayColor: UIColor = Appearance.bubbleOutgoingHighlightedSecondary,
//            incomingHighlightedSearchResultColor: UIColor = Appearance.bubbleIncomingHighlighted,
//            outgoingHighlightedSearchResultColor: UIColor = Appearance.bubbleOutgoingHighlighted,
//            incomingHighlightedOverlaySearchResultColor: UIColor = Appearance.bubbleIncomingHighlightedSecondary,
//            outgoingHighlightedOverlaySearchResultColor: UIColor = Appearance.bubbleOutgoingHighlightedSecondary,
//            overlayColor: UIColor = .overlayBackground2,
//            onOverlayColor: UIColor = .onPrimary,
//            reactionsContainerBackgroundColor: UIColor = .backgroundSections,
//            threadReplyArrowStrokeColor: UIColor = .border,
//            
//            // Label Appearances
//            senderNameLabelAppearance: LabelAppearance = .init(foregroundColor: nil, font: Fonts.semiBold.withSize(14)),
//            bodyLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.regular.withSize(16)),
//            mentionLabelAppearance: LabelAppearance = .init(foregroundColor: .accent, font: Fonts.regular.withSize(16)),
//            deletedMessageLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.with(traits: .traitItalic).withSize(16)),
//            messageDateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(12)),
//            messageStateLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.with(traits: .traitItalic).withSize(12)),
//            linkLabelAppearance: LabelAppearance = .init(foregroundColor: .systemBlue, font: Fonts.regular.withSize(16)),
//            linkPreviewAppearance: LinkPreviewAppearance = .init(
//                titleLabelAppearance: .init(foregroundColor: .primaryText, font: Fonts.semiBold.withSize(14)),
//                descriptionLabelAppearance: .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(13)),
//                highlightedLinkBackgroundColor: .footnoteText,
//                placeholderIcon: nil
//            ),
//            videoDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .onPrimary, font: Fonts.regular.withSize(12)),
//            threadReplyCountLabelAppearance: LabelAppearance = .init(foregroundColor: .accent, font: Fonts.semiBold.withSize(12)),
//            forwardedTitleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent, font: Fonts.semiBold.withSize(13)),
//            reactionCountLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.regular.withSize(13)),
//            voiceSpeedLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.semiBold.withSize(12), backgroundColor: .background),
//            voiceDurationLabelAppearance: LabelAppearance = .init(foregroundColor: .footnoteText, font: Fonts.regular.withSize(11)),
//            attachmentFileNameLabelAppearance: LabelAppearance = .init(foregroundColor: .primaryText, font: Fonts.semiBold.withSize(16)),
//            attachmentFileSizeLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText, font: Fonts.regular.withSize(12)),
//            
//            // Icons
//            messageDeliveryStatusIcons: MessageDeliveryStatusIcons = .init(),
//            viewCountIcon: UIImage = .eye,
//            videoIcon: UIImage = .galleryVideoAsset,
//            videoPlayIcon: UIImage = .videoPlay,
//            swipeToReplyIcon: UIImage = .channelReply,
//            forwardedIcon: UIImage = .forwardedMessage,
//            voicePlayIcon: UIImage = .audioPlayerPlay,
//            voicePauseIcon: UIImage = .audioPlayerPause,
//            
//            // Other Appearances
//            unreadMessagesSeparatorAppearance: UnreadMessagesSeparatorView.Appearance = .init(backgroundColor: Appearance.bubbleIncoming),
//            replyMessageAppearance: ReplyMessageAppearance = .init(),
//            checkboxAppearance: CheckBoxView.Appearance = CheckBoxView.appearance,
//            voiceWaveformViewAppearance: AudioWaveformView.Appearance = AudioWaveformView.appearance,
//            mediaLoaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
//                                                                           trackColor: .clear,
//                                                                           backgroundColor: .accent,
//                                                                           cancelIcon: nil,
//                                                                           uploadIcon: nil,
//                                                                           downloadIcon: nil),
//            overlayMediaLoaderAppearance: CircularProgressView.Appearance = .init(progressColor: .onPrimary,
//                                                                                  trackColor: .clear,
//                                                                                  backgroundColor: .overlayBackground2,
//                                                                                  cancelIcon: .attachmentTransferPause,
//                                                                                  uploadIcon: .attachmentUpload,
//                                                                                  downloadIcon: .attachmentDownload),
//            
//            // Other properties
//            editedStateText: String = L10n.Message.Info.edited,
//            deletedStateText: String = L10n.Message.deleted,
//            forwardedText: String = L10n.Message.Forward.title,
//            
//            // Formatters and providers
//            attachmentIconProvider: any AttachmentIconProviding = SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
//            senderNameColorProvider: any UserColorProviding = SceytChatUIKit.shared.visualProviders.senderNameColorProvider,
//            senderNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.userNameFormatter,
//            voiceDurationFormatter: any TimeIntervalFormatting = SceytChatUIKit.shared.formatters.mediaDurationFormatter,
//            attachmentFileSizeFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.attachmentSizeFormatter,
//            messageViewCountFormatter: any UIntFormatting = SceytChatUIKit.shared.formatters.messageViewCountFormatter,
//            messageDateFormatter: any DateFormatting = SceytChatUIKit.shared.formatters.messageDateFormatter,
//            mentionUserNameFormatter: any UserFormatting = SceytChatUIKit.shared.formatters.mentionUserNameFormatter,
//            userDefaultAvatarProvider: any UserAvatarProviding = SceytChatUIKit.shared.visualProviders.userAvatarProvider
//        ) {
//            // Colors
//            self.backgroundColor = backgroundColor
//            self.incomingBubbleColor = incomingBubbleColor
//            self.outgoingBubbleColor = outgoingBubbleColor
//            self.incomingReplyBackgroundColor = incomingReplyBackgroundColor
//            self.outgoingReplyBackgroundColor = outgoingReplyBackgroundColor
//            self.incomingLinkPreviewBackgroundColor = incomingLinkPreviewBackgroundColor
//            self.outgoingLinkPreviewBackgroundColor = outgoingLinkPreviewBackgroundColor
//            self.incomingHighlightedBubbleColor = incomingHighlightedBubbleColor
//            self.outgoingHighlightedBubbleColor = outgoingHighlightedBubbleColor
//            self.incomingHighlightedOverlayColor = incomingHighlightedOverlayColor
//            self.outgoingHighlightedOverlayColor = outgoingHighlightedOverlayColor
//            self.incomingHighlightedSearchResultColor = incomingHighlightedSearchResultColor
//            self.outgoingHighlightedSearchResultColor = outgoingHighlightedSearchResultColor
//            self.incomingHighlightedOverlaySearchResultColor = incomingHighlightedOverlaySearchResultColor
//            self.outgoingHighlightedOverlaySearchResultColor = outgoingHighlightedOverlaySearchResultColor
//            self.overlayColor = overlayColor
//            self.onOverlayColor = onOverlayColor
//            self.reactionsContainerBackgroundColor = reactionsContainerBackgroundColor
//            self.threadReplyArrowStrokeColor = threadReplyArrowStrokeColor
//            
//            // Label Appearances
//            self.senderNameLabelAppearance = senderNameLabelAppearance
//            self.bodyLabelAppearance = bodyLabelAppearance
//            self.mentionLabelAppearance = mentionLabelAppearance
//            self.deletedMessageLabelAppearance = deletedMessageLabelAppearance
//            self.messageDateLabelAppearance = messageDateLabelAppearance
//            self.messageStateLabelAppearance = messageStateLabelAppearance
//            self.linkLabelAppearance = linkLabelAppearance
//            self.linkPreviewAppearance = linkPreviewAppearance
//            self.videoDurationLabelAppearance = videoDurationLabelAppearance
//            self.threadReplyCountLabelAppearance = threadReplyCountLabelAppearance
//            self.forwardedTitleLabelAppearance = forwardedTitleLabelAppearance
//            self.reactionCountLabelAppearance = reactionCountLabelAppearance
//            self.voiceSpeedLabelAppearance = voiceSpeedLabelAppearance
//            self.voiceDurationLabelAppearance = voiceDurationLabelAppearance
//            self.attachmentFileNameLabelAppearance = attachmentFileNameLabelAppearance
//            self.attachmentFileSizeLabelAppearance = attachmentFileSizeLabelAppearance
//            
//            // Icons
//            self.messageDeliveryStatusIcons = messageDeliveryStatusIcons
//            self.viewCountIcon = viewCountIcon
//            self.videoIcon = videoIcon
//            self.videoPlayIcon = videoPlayIcon
//            self.swipeToReplyIcon = swipeToReplyIcon
//            self.forwardedIcon = forwardedIcon
//            self.voicePlayIcon = voicePlayIcon
//            self.voicePauseIcon = voicePauseIcon
//            
//            // Other Appearances
//            self.unreadMessagesSeparatorAppearance = unreadMessagesSeparatorAppearance
//            self.replyMessageAppearance = replyMessageAppearance
//            self.checkboxAppearance = checkboxAppearance
//            self.voiceWaveformViewAppearance = voiceWaveformViewAppearance
//            self.mediaLoaderAppearance = mediaLoaderAppearance
//            self.overlayMediaLoaderAppearance = overlayMediaLoaderAppearance
//            
//            // Other properties
//            self.editedStateText = editedStateText
//            self.deletedStateText = deletedStateText
//            self.forwardedText = forwardedText
//            
//            // Formatters and providers
//            self.attachmentIconProvider = attachmentIconProvider
//            self.senderNameColorProvider = senderNameColorProvider
//            self.senderNameFormatter = senderNameFormatter
//            self.voiceDurationFormatter = voiceDurationFormatter
//            self.attachmentFileSizeFormatter = attachmentFileSizeFormatter
//            self.messageViewCountFormatter = messageViewCountFormatter
//            self.messageDateFormatter = messageDateFormatter
//            self.mentionUserNameFormatter = mentionUserNameFormatter
//            self.userDefaultAvatarProvider = userDefaultAvatarProvider
//        }
//    }
//}
//
//


//
//  MessageCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 28.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell: AppearanceProviding {
    //    public static var appearance = Appearance(
    //        backgroundColor: .clear,
    //        incomingBubbleColor: DefaultColors.bubbleIncoming,
    //        outgoingBubbleColor: DefaultColors.bubbleOutgoing,
    //        incomingReplyBackgroundColor: DefaultColors.bubbleIncomingSecondary,
    //        outgoingReplyBackgroundColor: DefaultColors.bubbleOutgoingSecondary,
    //        incomingLinkPreviewBackgroundColor: DefaultColors.bubbleIncomingSecondary,
    //        outgoingLinkPreviewBackgroundColor: DefaultColors.bubbleOutgoingSecondary,
    //        incomingHighlightedBubbleColor: DefaultColors.bubbleIncomingHighlighted,
    //        outgoingHighlightedBubbleColor: DefaultColors.bubbleOutgoingHighlighted,
    //        incomingHighlightedOverlayColor: DefaultColors.bubbleIncomingHighlightedSecondary,
    //        outgoingHighlightedOverlayColor: DefaultColors.bubbleIncomingHighlightedSecondary,
    //        incomingHighlightedSearchResultColor: DefaultColors.bubbleIncomingHighlighted,
    //        outgoingHighlightedSearchResultColor: DefaultColors.bubbleOutgoingHighlighted,
    //        incomingHighlightedOverlaySearchResultColor: DefaultColors.bubbleIncomingHighlightedSecondary,
    //        outgoingHighlightedOverlaySearchResultColor: DefaultColors.bubbleOutgoingHighlightedSecondary,
    //        overlayColor: .overlayBackground2,
    //        onOverlayColor: .onPrimary,
    //        reactionsContainerBackgroundColor: .backgroundSections,
    //        threadReplyArrowStrokeColor: .border,
    //        senderNameLabelAppearance: LabelAppearance(
    //            foregroundColor: nil, // Will use randomized color from initials colors
    //            font: Fonts.semiBold.withSize(14)
    //        ),
    //        bodyLabelAppearance: LabelAppearance(
    //            foregroundColor: .primaryText,
    //            font: Fonts.regular.withSize(16)
    //        ),
    //        mentionLabelAppearance: LabelAppearance(
    //            foregroundColor: .accent,
    //            font: Fonts.regular.withSize(16)
    //        ),
    //        deletedMessageLabelAppearance: LabelAppearance(
    //            foregroundColor: .secondaryText,
    //            font: Fonts.regular.with(traits: .traitItalic).withSize(16)
    //        ),
    //        messageDateLabelAppearance: LabelAppearance(
    //            foregroundColor: .secondaryText,
    //            font: Fonts.regular.withSize(12)
    //        ),
    //        messageStateLabelAppearance: LabelAppearance(
    //            foregroundColor: .secondaryText,
    //            font: Fonts.regular.with(traits: .traitItalic).withSize(12)
    //        ),
    //        linkLabelAppearance: LabelAppearance(
    //            foregroundColor: .systemBlue,
    //            font: Fonts.regular.withSize(16)
    //        ),
    //        linkPreviewAppearance: LinkPreviewAppearance(
    //            titleLabelAppearance: LabelAppearance(
    //                foregroundColor: .primaryText,
    //                font: Fonts.semiBold.withSize(14)
    //            ),
    //            descriptionLabelAppearance: LabelAppearance(
    //                foregroundColor: .secondaryText,
    //                font: Fonts.regular.withSize(13)
    //            ),
    //            highlightedLinkBackgroundColor: .footnoteText,
    //            placeholderIcon: nil
    //        ),
    //        videoDurationLabelAppearance: LabelAppearance(
    //            foregroundColor: .onPrimary,
    //            font: Fonts.regular.withSize(12)
    //        ),
    //        threadReplyCountLabelAppearance: LabelAppearance(
    //            foregroundColor: .accent,
    //            font: Fonts.semiBold.withSize(12)
    //        ),
    //        forwardedTitleLabelAppearance: LabelAppearance(
    //            foregroundColor: .accent,
    //            font: Fonts.semiBold.withSize(13)
    //        ),
    //        reactionCountLabelAppearance: LabelAppearance(
    //            foregroundColor: .primaryText,
    //            font: Fonts.regular.withSize(13)
    //        ),
    //        voiceSpeedLabelAppearance: LabelAppearance(
    //            foregroundColor: .secondaryText,
    //            font: Fonts.semiBold.withSize(12),
    //            backgroundColor: .background
    //        ),
    //        voiceDurationLabelAppearance: LabelAppearance(
    //            foregroundColor: .footnoteText,
    //            font: Fonts.regular.withSize(11)
    //        ),
    //        attachmentFileNameLabelAppearance: LabelAppearance(
    //            foregroundColor: .primaryText,
    //            font: Fonts.semiBold.withSize(16)
    //        ),
    //        attachmentFileSizeLabelAppearance: LabelAppearance(
    //            foregroundColor: .secondaryText,
    //            font: Fonts.regular.withSize(12)
    //        ),
    //        messageDeliveryStatusIcons: MessageDeliveryStatusIcons(),
    //        viewCountIcon: .eye,
    //        videoIcon: .galleryVideoAsset,
    //        videoPlayIcon: .videoPlay,
    //        swipeToReplyIcon: .channelReply,
    //        forwardedIcon: .forwardedMessage,
    //        voicePlayIcon: .audioPlayerPlay,
    //        voicePauseIcon: .audioPlayerPause,
    //        unreadMessagesSeparatorAppearance: .init(unreadText: ""),
    //        replyMessageAppearance: ReplyMessageAppearance.appearance,
    //        checkboxAppearance: CheckBoxView.appearance,
    //        voiceWaveformViewAppearance: AudioWaveformView.appearance,
    //        mediaLoaderAppearance: CircularProgressView.Appearance(
    //            progressColor: .onPrimary,
    //            trackColor: .clear,
    //            backgroundColor: .accent,
    //            cancelIcon: nil,
    //            uploadIcon: nil,
    //            downloadIcon: nil
    //        ),
    //        overlayMediaLoaderAppearance: CircularProgressView.Appearance(
    //            progressColor: .onPrimary,
    //            trackColor: .clear,
    //            backgroundColor: .overlayBackground2,
    //            cancelIcon: .attachmentTransferPause,
    //            uploadIcon: .attachmentUpload,
    //            downloadIcon: .attachmentDownload
    //        ),
    //
    //        // Other properties
    //        editedStateText: L10n.Message.Info.edited,
    //        deletedStateText: L10n.Message.deleted,
    //        forwardedText: L10n.Message.Forward.title,
    //
    //        // Formatters and providers
    //        attachmentIconProvider: SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
    //        senderNameColorProvider: SceytChatUIKit.shared.visualProviders.senderNameColorProvider,
    //        senderNameFormatter: SceytChatUIKit.shared.formatters.userNameFormatter,
    //        voiceDurationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter,
    //        attachmentFileSizeFormatter: SceytChatUIKit.shared.formatters.attachmentSizeFormatter,
    //        messageViewCountFormatter: SceytChatUIKit.shared.formatters.messageViewCountFormatter,
    //        messageDateFormatter: SceytChatUIKit.shared.formatters.messageDateFormatter,
    //        mentionUserNameFormatter: SceytChatUIKit.shared.formatters.mentionUserNameFormatter,
    //        userDefaultAvatarProvider: SceytChatUIKit.shared.visualProviders.userAvatarProvider
    //    )
    public static var appearance = Appearance(
        // Colors
        backgroundColor: .clear,
        incomingBubbleColor: DefaultColors.bubbleIncoming,
        outgoingBubbleColor: DefaultColors.bubbleOutgoing,
        incomingReplyBackgroundColor: DefaultColors.bubbleIncomingSecondary,
        outgoingReplyBackgroundColor: DefaultColors.bubbleOutgoingSecondary,
        incomingLinkPreviewBackgroundColor: DefaultColors.bubbleIncomingSecondary,
        outgoingLinkPreviewBackgroundColor: DefaultColors.bubbleOutgoingSecondary,
        incomingHighlightedBubbleColor: DefaultColors.bubbleIncomingHighlighted,
        outgoingHighlightedBubbleColor: DefaultColors.bubbleOutgoingHighlighted,
        incomingHighlightedOverlayColor: DefaultColors.bubbleIncomingHighlightedSecondary,
        outgoingHighlightedOverlayColor: DefaultColors.bubbleIncomingHighlightedSecondary,
        incomingHighlightedSearchResultColor: DefaultColors.bubbleIncomingHighlighted,
        outgoingHighlightedSearchResultColor: DefaultColors.bubbleOutgoingHighlighted,
        incomingHighlightedOverlaySearchResultColor: DefaultColors.bubbleIncomingHighlightedSecondary,
        outgoingHighlightedOverlaySearchResultColor: DefaultColors.bubbleOutgoingHighlightedSecondary,
        overlayColor: .overlayBackground2,
        onOverlayColor: .onPrimary,
        reactionsContainerBackgroundColor: .backgroundSections,
        threadReplyArrowStrokeColor: .border,
        
        // Label Appearances
        senderNameLabelAppearance: LabelAppearance(
            foregroundColor: nil, // Will use randomized color from initials colors
            font: Fonts.semiBold.withSize(14)
        ),
        bodyLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(16)
        ),
        mentionLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.regular.withSize(16)
        ),
        deletedMessageLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.with(traits: .traitItalic).withSize(16)
        ),
        messageDateLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(12)
        ),
        messageStateLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.with(traits: .traitItalic).withSize(12)
        ),
        linkLabelAppearance: LabelAppearance(
            foregroundColor: .systemBlue,
            font: Fonts.regular.withSize(16)
        ),
        linkPreviewAppearance: LinkPreviewAppearance(
            titleLabelAppearance: LabelAppearance(
                foregroundColor: .primaryText,
                font: Fonts.semiBold.withSize(14)
            ),
            descriptionLabelAppearance: LabelAppearance(
                foregroundColor: .secondaryText,
                font: Fonts.regular.withSize(13)
            ),
            highlightedLinkBackgroundColor: .footnoteText,
            placeholderIcon: nil
        ),
        videoDurationLabelAppearance: LabelAppearance(
            foregroundColor: .onPrimary,
            font: Fonts.regular.withSize(12)
        ),
        threadReplyCountLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(12)
        ),
        forwardedTitleLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(13)
        ),
        reactionCountLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.regular.withSize(13)
        ),
        voiceSpeedLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.semiBold.withSize(12),
            backgroundColor: .background
        ),
        voiceDurationLabelAppearance: LabelAppearance(
            foregroundColor: .footnoteText,
            font: Fonts.regular.withSize(11)
        ),
        attachmentFileNameLabelAppearance: LabelAppearance(
            foregroundColor: .primaryText,
            font: Fonts.semiBold.withSize(16)
        ),
        attachmentFileSizeLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(12)
        ),
        
        // Icons
        messageDeliveryStatusIcons: MessageDeliveryStatusIcons(),
        viewCountIcon: .eye,
        videoIcon: .galleryVideoAsset,
        videoPlayIcon: .videoPlay,
        swipeToReplyIcon: .channelReply,
        forwardedIcon: .forwardedMessage,
        voicePlayIcon: .audioPlayerPlay,
        voicePauseIcon: .audioPlayerPause,
        
        // Other Appearances
        //        unreadMessagesSeparatorAppearance: MessageCell.UnreadMessagesSeparatorView.appearance,
        unreadMessagesSeparatorAppearance: UnreadMessagesSeparatorView.Appearance(), // review!!!
        replyMessageAppearance: ReplyMessageAppearance.appearance,
        checkboxAppearance: CheckBoxView.appearance,
        voiceWaveformViewAppearance: AudioWaveformView.appearance,
        mediaLoaderAppearance: CircularProgressView.Appearance(
            reference: CircularProgressView.appearance,
            progressColor: .onPrimary,
            trackColor: .clear,
            backgroundColor: .accent,
            cancelIcon: nil,
            uploadIcon: nil,
            downloadIcon: nil
        ),
        overlayMediaLoaderAppearance: CircularProgressView.Appearance(
            reference: CircularProgressView.appearance,
            progressColor: .onPrimary,
            trackColor: .clear,
            backgroundColor: .overlayBackground2,
            cancelIcon: .attachmentTransferPause,
            uploadIcon: .attachmentUpload,
            downloadIcon: .attachmentDownload
        ),
        
        // Other properties
        editedStateText: L10n.Message.Info.edited,
        deletedStateText: L10n.Message.deleted,
        forwardedText: L10n.Message.Forward.title,
        
        // Formatters and providers
        attachmentIconProvider: SceytChatUIKit.shared.visualProviders.attachmentIconProvider,
        senderNameColorProvider: SceytChatUIKit.shared.visualProviders.senderNameColorProvider,
        senderNameFormatter: SceytChatUIKit.shared.formatters.userNameFormatter,
        voiceDurationFormatter: SceytChatUIKit.shared.formatters.mediaDurationFormatter,
        attachmentFileSizeFormatter: SceytChatUIKit.shared.formatters.attachmentSizeFormatter,
        messageViewCountFormatter: SceytChatUIKit.shared.formatters.messageViewCountFormatter,
        messageDateFormatter: SceytChatUIKit.shared.formatters.messageDateFormatter,
        mentionUserNameFormatter: SceytChatUIKit.shared.formatters.mentionUserNameFormatter,
        userDefaultAvatarProvider: SceytChatUIKit.shared.visualProviders.userAvatarProvider
    )
    
    public struct Appearance {
        // Colors
        @Trackable<Appearance, UIColor>
        public var backgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var incomingBubbleColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var outgoingBubbleColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var incomingReplyBackgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var outgoingReplyBackgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var incomingLinkPreviewBackgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var outgoingLinkPreviewBackgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var incomingHighlightedBubbleColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var outgoingHighlightedBubbleColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var incomingHighlightedOverlayColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var outgoingHighlightedOverlayColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var incomingHighlightedSearchResultColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var outgoingHighlightedSearchResultColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var incomingHighlightedOverlaySearchResultColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var outgoingHighlightedOverlaySearchResultColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var overlayColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var onOverlayColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var reactionsContainerBackgroundColor: UIColor
        
        @Trackable<Appearance, UIColor>
        public var threadReplyArrowStrokeColor: UIColor
        
        // Label Appearances
        @Trackable<Appearance, LabelAppearance>
        public var senderNameLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var bodyLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var mentionLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var deletedMessageLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var messageDateLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var messageStateLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var linkLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LinkPreviewAppearance>
        public var linkPreviewAppearance: LinkPreviewAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var videoDurationLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var threadReplyCountLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var forwardedTitleLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var reactionCountLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var voiceSpeedLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var voiceDurationLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var attachmentFileNameLabelAppearance: LabelAppearance
        
        @Trackable<Appearance, LabelAppearance>
        public var attachmentFileSizeLabelAppearance: LabelAppearance
        
        // Icons
        @Trackable<Appearance, MessageDeliveryStatusIcons>
        public var messageDeliveryStatusIcons: MessageDeliveryStatusIcons
        
        @Trackable<Appearance, UIImage>
        public var viewCountIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var videoIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var videoPlayIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var swipeToReplyIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var forwardedIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var voicePlayIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var voicePauseIcon: UIImage
        
        // Other Appearances
        @Trackable<Appearance, UnreadMessagesSeparatorView.Appearance>
        public var unreadMessagesSeparatorAppearance: UnreadMessagesSeparatorView.Appearance
        
        @Trackable<Appearance, ReplyMessageAppearance>
        public var replyMessageAppearance: ReplyMessageAppearance
        
        @Trackable<Appearance, CheckBoxView.Appearance>
        public var checkboxAppearance: CheckBoxView.Appearance
        
        @Trackable<Appearance, AudioWaveformView.Appearance>
        public var voiceWaveformViewAppearance: AudioWaveformView.Appearance
        
        @Trackable<Appearance, CircularProgressView.Appearance>
        public var mediaLoaderAppearance: CircularProgressView.Appearance
        
        @Trackable<Appearance, CircularProgressView.Appearance>
        public var overlayMediaLoaderAppearance: CircularProgressView.Appearance
        
        // Other properties
        @Trackable<Appearance, String>
        public var editedStateText: String
        
        @Trackable<Appearance, String>
        public var deletedStateText: String
        
        @Trackable<Appearance, String>
        public var forwardedText: String
        
        // Formatters and providers
        @Trackable<Appearance, any AttachmentIconProviding>
        public var attachmentIconProvider: any AttachmentIconProviding
        
        @Trackable<Appearance, any UserColorProviding>
        public var senderNameColorProvider: any UserColorProviding
        
        @Trackable<Appearance, any UserFormatting>
        public var senderNameFormatter: any UserFormatting
        
        @Trackable<Appearance, any TimeIntervalFormatting>
        public var voiceDurationFormatter: any TimeIntervalFormatting
        
        @Trackable<Appearance, any UIntFormatting>
        public var attachmentFileSizeFormatter: any UIntFormatting
        
        @Trackable<Appearance, any UIntFormatting>
        public var messageViewCountFormatter: any UIntFormatting
        
        @Trackable<Appearance, any DateFormatting>
        public var messageDateFormatter: any DateFormatting
        
        @Trackable<Appearance, any UserFormatting>
        public var mentionUserNameFormatter: any UserFormatting
        
        @Trackable<Appearance, any UserAvatarProviding>
        public var userDefaultAvatarProvider: any UserAvatarProviding
        
        // Initializer with all parameters
        public init(
            // Colors
            backgroundColor: UIColor,
            incomingBubbleColor: UIColor,
            outgoingBubbleColor: UIColor,
            incomingReplyBackgroundColor: UIColor,
            outgoingReplyBackgroundColor: UIColor,
            incomingLinkPreviewBackgroundColor: UIColor,
            outgoingLinkPreviewBackgroundColor: UIColor,
            incomingHighlightedBubbleColor: UIColor,
            outgoingHighlightedBubbleColor: UIColor,
            incomingHighlightedOverlayColor: UIColor,
            outgoingHighlightedOverlayColor: UIColor,
            incomingHighlightedSearchResultColor: UIColor,
            outgoingHighlightedSearchResultColor: UIColor,
            incomingHighlightedOverlaySearchResultColor: UIColor,
            outgoingHighlightedOverlaySearchResultColor: UIColor,
            overlayColor: UIColor,
            onOverlayColor: UIColor,
            reactionsContainerBackgroundColor: UIColor,
            threadReplyArrowStrokeColor: UIColor,
            
            // Label Appearances
            senderNameLabelAppearance: LabelAppearance,
            bodyLabelAppearance: LabelAppearance,
            mentionLabelAppearance: LabelAppearance,
            deletedMessageLabelAppearance: LabelAppearance,
            messageDateLabelAppearance: LabelAppearance,
            messageStateLabelAppearance: LabelAppearance,
            linkLabelAppearance: LabelAppearance,
            linkPreviewAppearance: LinkPreviewAppearance,
            videoDurationLabelAppearance: LabelAppearance,
            threadReplyCountLabelAppearance: LabelAppearance,
            forwardedTitleLabelAppearance: LabelAppearance,
            reactionCountLabelAppearance: LabelAppearance,
            voiceSpeedLabelAppearance: LabelAppearance,
            voiceDurationLabelAppearance: LabelAppearance,
            attachmentFileNameLabelAppearance: LabelAppearance,
            attachmentFileSizeLabelAppearance: LabelAppearance,
            
            // Icons
            messageDeliveryStatusIcons: MessageDeliveryStatusIcons,
            viewCountIcon: UIImage,
            videoIcon: UIImage,
            videoPlayIcon: UIImage,
            swipeToReplyIcon: UIImage,
            forwardedIcon: UIImage,
            voicePlayIcon: UIImage,
            voicePauseIcon: UIImage,
            
            // Other Appearances
            unreadMessagesSeparatorAppearance: MessageCell.UnreadMessagesSeparatorView.Appearance,
            replyMessageAppearance: ReplyMessageAppearance,
            checkboxAppearance: CheckBoxView.Appearance,
            voiceWaveformViewAppearance: AudioWaveformView.Appearance,
            mediaLoaderAppearance: CircularProgressView.Appearance,
            overlayMediaLoaderAppearance: CircularProgressView.Appearance,
            
            // Other properties
            editedStateText: String,
            deletedStateText: String,
            forwardedText: String,
            
            // Formatters and providers
            attachmentIconProvider: any AttachmentIconProviding,
            senderNameColorProvider: any UserColorProviding,
            senderNameFormatter: any UserFormatting,
            voiceDurationFormatter: any TimeIntervalFormatting,
            attachmentFileSizeFormatter: any UIntFormatting,
            messageViewCountFormatter: any UIntFormatting,
            messageDateFormatter: any DateFormatting,
            mentionUserNameFormatter: any UserFormatting,
            userDefaultAvatarProvider: any UserAvatarProviding
        ) {
            // Colors
            self._backgroundColor = Trackable(value: backgroundColor)
            self._incomingBubbleColor = Trackable(value: incomingBubbleColor)
            self._outgoingBubbleColor = Trackable(value: outgoingBubbleColor)
            self._incomingReplyBackgroundColor = Trackable(value: incomingReplyBackgroundColor)
            self._outgoingReplyBackgroundColor = Trackable(value: outgoingReplyBackgroundColor)
            self._incomingLinkPreviewBackgroundColor = Trackable(value: incomingLinkPreviewBackgroundColor)
            self._outgoingLinkPreviewBackgroundColor = Trackable(value: outgoingLinkPreviewBackgroundColor)
            self._incomingHighlightedBubbleColor = Trackable(value: incomingHighlightedBubbleColor)
            self._outgoingHighlightedBubbleColor = Trackable(value: outgoingHighlightedBubbleColor)
            self._incomingHighlightedOverlayColor = Trackable(value: incomingHighlightedOverlayColor)
            self._outgoingHighlightedOverlayColor = Trackable(value: outgoingHighlightedOverlayColor)
            self._incomingHighlightedSearchResultColor = Trackable(value: incomingHighlightedSearchResultColor)
            self._outgoingHighlightedSearchResultColor = Trackable(value: outgoingHighlightedSearchResultColor)
            self._incomingHighlightedOverlaySearchResultColor = Trackable(value: incomingHighlightedOverlaySearchResultColor)
            self._outgoingHighlightedOverlaySearchResultColor = Trackable(value: outgoingHighlightedOverlaySearchResultColor)
            self._overlayColor = Trackable(value: overlayColor)
            self._onOverlayColor = Trackable(value: onOverlayColor)
            self._reactionsContainerBackgroundColor = Trackable(value: reactionsContainerBackgroundColor)
            self._threadReplyArrowStrokeColor = Trackable(value: threadReplyArrowStrokeColor)
            
            // Label Appearances
            self._senderNameLabelAppearance = Trackable(value: senderNameLabelAppearance)
            self._bodyLabelAppearance = Trackable(value: bodyLabelAppearance)
            self._mentionLabelAppearance = Trackable(value: mentionLabelAppearance)
            self._deletedMessageLabelAppearance = Trackable(value: deletedMessageLabelAppearance)
            self._messageDateLabelAppearance = Trackable(value: messageDateLabelAppearance)
            self._messageStateLabelAppearance = Trackable(value: messageStateLabelAppearance)
            self._linkLabelAppearance = Trackable(value: linkLabelAppearance)
            self._linkPreviewAppearance = Trackable(value: linkPreviewAppearance)
            self._videoDurationLabelAppearance = Trackable(value: videoDurationLabelAppearance)
            self._threadReplyCountLabelAppearance = Trackable(value: threadReplyCountLabelAppearance)
            self._forwardedTitleLabelAppearance = Trackable(value: forwardedTitleLabelAppearance)
            self._reactionCountLabelAppearance = Trackable(value: reactionCountLabelAppearance)
            self._voiceSpeedLabelAppearance = Trackable(value: voiceSpeedLabelAppearance)
            self._voiceDurationLabelAppearance = Trackable(value: voiceDurationLabelAppearance)
            self._attachmentFileNameLabelAppearance = Trackable(value: attachmentFileNameLabelAppearance)
            self._attachmentFileSizeLabelAppearance = Trackable(value: attachmentFileSizeLabelAppearance)
            
            // Icons
            self._messageDeliveryStatusIcons = Trackable(value: messageDeliveryStatusIcons)
            self._viewCountIcon = Trackable(value: viewCountIcon)
            self._videoIcon = Trackable(value: videoIcon)
            self._videoPlayIcon = Trackable(value: videoPlayIcon)
            self._swipeToReplyIcon = Trackable(value: swipeToReplyIcon)
            self._forwardedIcon = Trackable(value: forwardedIcon)
            self._voicePlayIcon = Trackable(value: voicePlayIcon)
            self._voicePauseIcon = Trackable(value: voicePauseIcon)
            
            // Other Appearances
            self._unreadMessagesSeparatorAppearance = Trackable(value: unreadMessagesSeparatorAppearance)
            self._replyMessageAppearance = Trackable(value: replyMessageAppearance)
            self._checkboxAppearance = Trackable(value: checkboxAppearance)
            self._voiceWaveformViewAppearance = Trackable(value: voiceWaveformViewAppearance)
            self._mediaLoaderAppearance = Trackable(value: mediaLoaderAppearance)
            self._overlayMediaLoaderAppearance = Trackable(value: overlayMediaLoaderAppearance)
            
            // Other properties
            self._editedStateText = Trackable(value: editedStateText)
            self._deletedStateText = Trackable(value: deletedStateText)
            self._forwardedText = Trackable(value: forwardedText)
            
            // Formatters and providers
            self._attachmentIconProvider = Trackable(value: attachmentIconProvider)
            self._senderNameColorProvider = Trackable(value: senderNameColorProvider)
            self._senderNameFormatter = Trackable(value: senderNameFormatter)
            self._voiceDurationFormatter = Trackable(value: voiceDurationFormatter)
            self._attachmentFileSizeFormatter = Trackable(value: attachmentFileSizeFormatter)
            self._messageViewCountFormatter = Trackable(value: messageViewCountFormatter)
            self._messageDateFormatter = Trackable(value: messageDateFormatter)
            self._mentionUserNameFormatter = Trackable(value: mentionUserNameFormatter)
            self._userDefaultAvatarProvider = Trackable(value: userDefaultAvatarProvider)
        }
        
        // Initializer with optional parameters
        public init(
            // Colors
            reference: MessageCell.Appearance,
            backgroundColor: UIColor? = nil,
            incomingBubbleColor: UIColor? = nil,
            outgoingBubbleColor: UIColor? = nil,
            incomingReplyBackgroundColor: UIColor? = nil,
            outgoingReplyBackgroundColor: UIColor? = nil,
            incomingLinkPreviewBackgroundColor: UIColor? = nil,
            outgoingLinkPreviewBackgroundColor: UIColor? = nil,
            incomingHighlightedBubbleColor: UIColor? = nil,
            outgoingHighlightedBubbleColor: UIColor? = nil,
            incomingHighlightedOverlayColor: UIColor? = nil,
            outgoingHighlightedOverlayColor: UIColor? = nil,
            incomingHighlightedSearchResultColor: UIColor? = nil,
            outgoingHighlightedSearchResultColor: UIColor? = nil,
            incomingHighlightedOverlaySearchResultColor: UIColor? = nil,
            outgoingHighlightedOverlaySearchResultColor: UIColor? = nil,
            overlayColor: UIColor? = nil,
            onOverlayColor: UIColor? = nil,
            reactionsContainerBackgroundColor: UIColor? = nil,
            threadReplyArrowStrokeColor: UIColor? = nil,
            
            // Label Appearances
            senderNameLabelAppearance: LabelAppearance? = nil,
            bodyLabelAppearance: LabelAppearance? = nil,
            mentionLabelAppearance: LabelAppearance? = nil,
            deletedMessageLabelAppearance: LabelAppearance? = nil,
            messageDateLabelAppearance: LabelAppearance? = nil,
            messageStateLabelAppearance: LabelAppearance? = nil,
            linkLabelAppearance: LabelAppearance? = nil,
            linkPreviewAppearance: LinkPreviewAppearance? = nil,
            videoDurationLabelAppearance: LabelAppearance? = nil,
            threadReplyCountLabelAppearance: LabelAppearance? = nil,
            forwardedTitleLabelAppearance: LabelAppearance? = nil,
            reactionCountLabelAppearance: LabelAppearance? = nil,
            voiceSpeedLabelAppearance: LabelAppearance? = nil,
            voiceDurationLabelAppearance: LabelAppearance? = nil,
            attachmentFileNameLabelAppearance: LabelAppearance? = nil,
            attachmentFileSizeLabelAppearance: LabelAppearance? = nil,
            
            // Icons
            messageDeliveryStatusIcons: MessageDeliveryStatusIcons? = nil,
            viewCountIcon: UIImage? = nil,
            videoIcon: UIImage? = nil,
            videoPlayIcon: UIImage? = nil,
            swipeToReplyIcon: UIImage? = nil,
            forwardedIcon: UIImage? = nil,
            voicePlayIcon: UIImage? = nil,
            voicePauseIcon: UIImage? = nil,
            
            // Other Appearances
            unreadMessagesSeparatorAppearance: MessageCell.UnreadMessagesSeparatorView.Appearance? = nil,
            replyMessageAppearance: ReplyMessageAppearance? = nil,
            checkboxAppearance: CheckBoxView.Appearance? = nil,
            voiceWaveformViewAppearance: AudioWaveformView.Appearance? = nil,
            mediaLoaderAppearance: CircularProgressView.Appearance? = nil,
            overlayMediaLoaderAppearance: CircularProgressView.Appearance? = nil,
            
            // Other properties
            editedStateText: String? = nil,
            deletedStateText: String? = nil,
            forwardedText: String? = nil,
            
            // Formatters and providers
            attachmentIconProvider: (any AttachmentIconProviding)? = nil,
            senderNameColorProvider: (any UserColorProviding)? = nil,
            senderNameFormatter: (any UserFormatting)? = nil,
            voiceDurationFormatter: (any TimeIntervalFormatting)? = nil,
            attachmentFileSizeFormatter: (any UIntFormatting)? = nil,
            messageViewCountFormatter: (any UIntFormatting)? = nil,
            messageDateFormatter: (any DateFormatting)? = nil,
            mentionUserNameFormatter: (any UserFormatting)? = nil,
            userDefaultAvatarProvider: (any UserAvatarProviding)? = nil
        ) {
            // Colors
            self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
            self._incomingBubbleColor = Trackable(reference: reference, referencePath: \.incomingBubbleColor)
            self._outgoingBubbleColor = Trackable(reference: reference, referencePath: \.outgoingBubbleColor)
            self._incomingReplyBackgroundColor = Trackable(reference: reference, referencePath: \.incomingReplyBackgroundColor)
            self._outgoingReplyBackgroundColor = Trackable(reference: reference, referencePath: \.outgoingReplyBackgroundColor)
            self._incomingLinkPreviewBackgroundColor = Trackable(reference: reference, referencePath: \.incomingLinkPreviewBackgroundColor)
            self._outgoingLinkPreviewBackgroundColor = Trackable(reference: reference, referencePath: \.outgoingLinkPreviewBackgroundColor)
            self._incomingHighlightedBubbleColor = Trackable(reference: reference, referencePath: \.incomingHighlightedBubbleColor)
            self._outgoingHighlightedBubbleColor = Trackable(reference: reference, referencePath: \.outgoingHighlightedBubbleColor)
            self._incomingHighlightedOverlayColor = Trackable(reference: reference, referencePath: \.incomingHighlightedOverlayColor)
            self._outgoingHighlightedOverlayColor = Trackable(reference: reference, referencePath: \.outgoingHighlightedOverlayColor)
            self._incomingHighlightedSearchResultColor = Trackable(reference: reference, referencePath: \.incomingHighlightedSearchResultColor)
            self._outgoingHighlightedSearchResultColor = Trackable(reference: reference, referencePath: \.outgoingHighlightedSearchResultColor)
            self._incomingHighlightedOverlaySearchResultColor = Trackable(reference: reference, referencePath: \.incomingHighlightedOverlaySearchResultColor)
            self._outgoingHighlightedOverlaySearchResultColor = Trackable(reference: reference, referencePath: \.outgoingHighlightedOverlaySearchResultColor)
            self._overlayColor = Trackable(reference: reference, referencePath: \.overlayColor)
            self._onOverlayColor = Trackable(reference: reference, referencePath: \.onOverlayColor)
            self._reactionsContainerBackgroundColor = Trackable(reference: reference, referencePath: \.reactionsContainerBackgroundColor)
            self._threadReplyArrowStrokeColor = Trackable(reference: reference, referencePath: \.threadReplyArrowStrokeColor)
            self._senderNameLabelAppearance = Trackable(reference: reference, referencePath: \.senderNameLabelAppearance)
            self._bodyLabelAppearance = Trackable(reference: reference, referencePath: \.bodyLabelAppearance)
            self._mentionLabelAppearance = Trackable(reference: reference, referencePath: \.mentionLabelAppearance)
            self._deletedMessageLabelAppearance = Trackable(reference: reference, referencePath: \.deletedMessageLabelAppearance)
            self._messageDateLabelAppearance = Trackable(reference: reference, referencePath: \.messageDateLabelAppearance)
            self._messageStateLabelAppearance = Trackable(reference: reference, referencePath: \.messageStateLabelAppearance)
            self._linkLabelAppearance = Trackable(reference: reference, referencePath: \.linkLabelAppearance)
            self._linkPreviewAppearance = Trackable(reference: reference, referencePath: \.linkPreviewAppearance)
            self._videoDurationLabelAppearance = Trackable(reference: reference, referencePath: \.videoDurationLabelAppearance)
            self._threadReplyCountLabelAppearance = Trackable(reference: reference, referencePath: \.threadReplyCountLabelAppearance)
            self._forwardedTitleLabelAppearance = Trackable(reference: reference, referencePath: \.forwardedTitleLabelAppearance)
            self._reactionCountLabelAppearance = Trackable(reference: reference, referencePath: \.reactionCountLabelAppearance)
            self._voiceSpeedLabelAppearance = Trackable(reference: reference, referencePath: \.voiceSpeedLabelAppearance)
            self._voiceDurationLabelAppearance = Trackable(reference: reference, referencePath: \.voiceDurationLabelAppearance)
            self._attachmentFileNameLabelAppearance = Trackable(reference: reference, referencePath: \.attachmentFileNameLabelAppearance)
            self._attachmentFileSizeLabelAppearance = Trackable(reference: reference, referencePath: \.attachmentFileSizeLabelAppearance)
            self._messageDeliveryStatusIcons = Trackable(reference: reference, referencePath: \.messageDeliveryStatusIcons)
            self._viewCountIcon = Trackable(reference: reference, referencePath: \.viewCountIcon)
            self._videoIcon = Trackable(reference: reference, referencePath: \.videoIcon)
            self._videoPlayIcon = Trackable(reference: reference, referencePath: \.videoPlayIcon)
            self._swipeToReplyIcon = Trackable(reference: reference, referencePath: \.swipeToReplyIcon)
            self._forwardedIcon = Trackable(reference: reference, referencePath: \.forwardedIcon)
            self._voicePlayIcon = Trackable(reference: reference, referencePath: \.voicePlayIcon)
            self._voicePauseIcon = Trackable(reference: reference, referencePath: \.voicePauseIcon)
            self._unreadMessagesSeparatorAppearance = Trackable(reference: reference, referencePath: \.unreadMessagesSeparatorAppearance)
            self._replyMessageAppearance = Trackable(reference: reference, referencePath: \.replyMessageAppearance)
            self._checkboxAppearance = Trackable(reference: reference, referencePath: \.checkboxAppearance)
            self._voiceWaveformViewAppearance = Trackable(reference: reference, referencePath: \.voiceWaveformViewAppearance)
            self._mediaLoaderAppearance = Trackable(reference: reference, referencePath: \.mediaLoaderAppearance)
            self._overlayMediaLoaderAppearance = Trackable(reference: reference, referencePath: \.overlayMediaLoaderAppearance)
            self._editedStateText = Trackable(reference: reference, referencePath: \.editedStateText)
            self._deletedStateText = Trackable(reference: reference, referencePath: \.deletedStateText)
            self._forwardedText = Trackable(reference: reference, referencePath: \.forwardedText)
            self._attachmentIconProvider = Trackable(reference: reference, referencePath: \.attachmentIconProvider)
            self._senderNameColorProvider = Trackable(reference: reference, referencePath: \.senderNameColorProvider)
            self._senderNameFormatter = Trackable(reference: reference, referencePath: \.senderNameFormatter)
            self._voiceDurationFormatter = Trackable(reference: reference, referencePath: \.voiceDurationFormatter)
            self._attachmentFileSizeFormatter = Trackable(reference: reference, referencePath: \.attachmentFileSizeFormatter)
            self._messageViewCountFormatter = Trackable(reference: reference, referencePath: \.messageViewCountFormatter)
            self._messageDateFormatter = Trackable(reference: reference, referencePath: \.messageDateFormatter)
            self._mentionUserNameFormatter = Trackable(reference: reference, referencePath: \.mentionUserNameFormatter)
            self._userDefaultAvatarProvider = Trackable(reference: reference, referencePath: \.userDefaultAvatarProvider)
            
            if let backgroundColor { self.backgroundColor = backgroundColor }
            if let incomingBubbleColor { self.incomingBubbleColor = incomingBubbleColor }
            if let outgoingBubbleColor { self.outgoingBubbleColor = outgoingBubbleColor }
            if let incomingReplyBackgroundColor { self.incomingReplyBackgroundColor = incomingReplyBackgroundColor }
            if let outgoingReplyBackgroundColor { self.outgoingReplyBackgroundColor = outgoingReplyBackgroundColor }
            if let incomingLinkPreviewBackgroundColor { self.incomingLinkPreviewBackgroundColor = incomingLinkPreviewBackgroundColor }
            if let outgoingLinkPreviewBackgroundColor { self.outgoingLinkPreviewBackgroundColor = outgoingLinkPreviewBackgroundColor }
            if let incomingHighlightedBubbleColor { self.incomingHighlightedBubbleColor = incomingHighlightedBubbleColor }
            if let outgoingHighlightedBubbleColor { self.outgoingHighlightedBubbleColor = outgoingHighlightedBubbleColor }
            if let incomingHighlightedOverlayColor { self.incomingHighlightedOverlayColor = incomingHighlightedOverlayColor }
            if let outgoingHighlightedOverlayColor { self.outgoingHighlightedOverlayColor = outgoingHighlightedOverlayColor }
            if let incomingHighlightedSearchResultColor { self.incomingHighlightedSearchResultColor = incomingHighlightedSearchResultColor }
            if let outgoingHighlightedSearchResultColor { self.outgoingHighlightedSearchResultColor = outgoingHighlightedSearchResultColor }
            if let incomingHighlightedOverlaySearchResultColor { self.incomingHighlightedOverlaySearchResultColor = incomingHighlightedOverlaySearchResultColor }
            if let outgoingHighlightedOverlaySearchResultColor { self.outgoingHighlightedOverlaySearchResultColor = outgoingHighlightedOverlaySearchResultColor }
            if let overlayColor { self.overlayColor = overlayColor }
            if let onOverlayColor { self.onOverlayColor = onOverlayColor }
            if let reactionsContainerBackgroundColor { self.reactionsContainerBackgroundColor = reactionsContainerBackgroundColor }
            if let threadReplyArrowStrokeColor { self.threadReplyArrowStrokeColor = threadReplyArrowStrokeColor }
            if let senderNameLabelAppearance { self.senderNameLabelAppearance = senderNameLabelAppearance }
            if let bodyLabelAppearance { self.bodyLabelAppearance = bodyLabelAppearance }
            if let mentionLabelAppearance { self.mentionLabelAppearance = mentionLabelAppearance }
            if let deletedMessageLabelAppearance { self.deletedMessageLabelAppearance = deletedMessageLabelAppearance }
            if let messageDateLabelAppearance { self.messageDateLabelAppearance = messageDateLabelAppearance }
            if let messageStateLabelAppearance { self.messageStateLabelAppearance = messageStateLabelAppearance }
            if let linkLabelAppearance { self.linkLabelAppearance = linkLabelAppearance }
            if let linkPreviewAppearance { self.linkPreviewAppearance = linkPreviewAppearance }
            if let videoDurationLabelAppearance { self.videoDurationLabelAppearance = videoDurationLabelAppearance }
            if let threadReplyCountLabelAppearance { self.threadReplyCountLabelAppearance = threadReplyCountLabelAppearance }
            if let forwardedTitleLabelAppearance { self.forwardedTitleLabelAppearance = forwardedTitleLabelAppearance }
            if let reactionCountLabelAppearance { self.reactionCountLabelAppearance = reactionCountLabelAppearance }
            if let voiceSpeedLabelAppearance { self.voiceSpeedLabelAppearance = voiceSpeedLabelAppearance }
            if let voiceDurationLabelAppearance { self.voiceDurationLabelAppearance = voiceDurationLabelAppearance }
            if let attachmentFileNameLabelAppearance { self.attachmentFileNameLabelAppearance = attachmentFileNameLabelAppearance }
            if let attachmentFileSizeLabelAppearance { self.attachmentFileSizeLabelAppearance = attachmentFileSizeLabelAppearance }
            if let messageDeliveryStatusIcons { self.messageDeliveryStatusIcons = messageDeliveryStatusIcons }
            if let viewCountIcon { self.viewCountIcon = viewCountIcon }
            if let videoIcon { self.videoIcon = videoIcon }
            if let videoPlayIcon { self.videoPlayIcon = videoPlayIcon }
            if let swipeToReplyIcon { self.swipeToReplyIcon = swipeToReplyIcon }
            if let forwardedIcon { self.forwardedIcon = forwardedIcon }
            if let voicePlayIcon { self.voicePlayIcon = voicePlayIcon }
            if let voicePauseIcon { self.voicePauseIcon = voicePauseIcon }
            if let unreadMessagesSeparatorAppearance { self.unreadMessagesSeparatorAppearance = unreadMessagesSeparatorAppearance }
            if let replyMessageAppearance { self.replyMessageAppearance = replyMessageAppearance }
            if let checkboxAppearance { self.checkboxAppearance = checkboxAppearance }
            if let voiceWaveformViewAppearance { self.voiceWaveformViewAppearance = voiceWaveformViewAppearance }
            if let mediaLoaderAppearance { self.mediaLoaderAppearance = mediaLoaderAppearance }
            if let overlayMediaLoaderAppearance { self.overlayMediaLoaderAppearance = overlayMediaLoaderAppearance }
            if let editedStateText { self.editedStateText = editedStateText }
            if let deletedStateText { self.deletedStateText = deletedStateText }
            if let forwardedText { self.forwardedText = forwardedText }
            if let attachmentIconProvider { self.attachmentIconProvider = attachmentIconProvider }
            if let senderNameColorProvider { self.senderNameColorProvider = senderNameColorProvider }
            if let senderNameFormatter { self.senderNameFormatter = senderNameFormatter }
            if let voiceDurationFormatter { self.voiceDurationFormatter = voiceDurationFormatter }
            if let attachmentFileSizeFormatter { self.attachmentFileSizeFormatter = attachmentFileSizeFormatter }
            if let messageViewCountFormatter { self.messageViewCountFormatter = messageViewCountFormatter }
            if let messageDateFormatter { self.messageDateFormatter = messageDateFormatter }
            if let mentionUserNameFormatter { self.mentionUserNameFormatter = mentionUserNameFormatter }
            if let userDefaultAvatarProvider { self.userDefaultAvatarProvider = userDefaultAvatarProvider }
        }
    }
}
