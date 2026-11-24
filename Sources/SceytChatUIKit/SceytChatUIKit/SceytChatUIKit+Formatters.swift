//
//  SceytChatUIKit+Formatters.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension SceytChatUIKit {
    public struct Formatters {
        public var userNameFormatter: any UserFormatting = UserNameFormatter()
        
        public var userShortNameFormatter: any UserFormatting = UserShortNameFormatter()
        
        public var userPresenceDateFormatter: any UserFormatting = UserPresenceDateFormatter()
        
        public var channelDateFormatter: any DateFormatting = ChannelDateFormatter()

        public var globalSearchMessageDateFormatter: any DateFormatting = GlobalSearchMessageDateFormatter()
        
        public var channelNameFormatter: any ChannelFormatting = ChannelNameFormatter()
        
        public var channelSubtitleFormatter: any ChannelFormatting = ChannelSubtitleFormatter()
        
        public var unreadCountFormatter: any UIntFormatting = UnreadCountFormatter()
        
        public var messageInfoDateFormatter: any DateFormatting = MessageInfoDateFormatter()
        
        public var messageInfoMarkerDateFormatter: any DateFormatting = MediaPreviewDateFormatter()
        
        public var messageViewCountFormatter: any UIntFormatting = MessageViewsCountFormatter()
        
        public var channelLastMessageSenderNameFormatter: any ChannelFormatting = ChannelLastMessageSenderNameFormatter()
        
        public var mentionUserNameFormatter: any UserFormatting = UserNameFormatter()
        
        public var replyUserNameFormatter: any UserFormatting = ReplyUserNameFormatter()
        
        public var reactedUserNameFormatter: any ChannelFormatting = ReactedUserNameFormatter()
        
        public var reactionFormatter: any ReactionFormatting = ReactionFormatter()
        
        public var typingUserNameFormatter: any UserFormatting = UserShortNameFormatter()

        public var mediaDurationFormatter: any TimeIntervalFormatting = MediaDurationFormatter()
        
        public var timeIntervalFormatter: any TimeIntervalFormatting = TimeIntervalFormatter()

        public var attachmentSizeFormatter: any UIntFormatting = FileSizeFormatter()

        public var avatarInitialsFormatter: any StringFormatting = AvatarInitialsFormatter()
        
        public var messageDateSeparatorFormatter: any DateFormatting = MessageDateSeparatorFormatter()

        public var messageDateFormatter: any DateFormatting = MessageDateFormatter()
        
        public var messageShareBodyFormatter: any MessageFormatting = MessageShareBodyFormatter()

        public var channelInfoAttachmentDateFormatter: any DateFormatting = ChannelInfoMediaDateFormatter()

        public var channelInfoAttachmentSeparatorDateFormatter: any DateFormatting = ChannelInfoMediaSeparatorDateFormatter()

        public var mediaPreviewDateFormatter: any DateFormatting = MediaPreviewDateFormatter()
        
        public var attachmentNameFormatter: any AttachmentFormatting = AttachmentNameFormatter()
        
        public var attachmentFileNameFormatter: any AttachmentFormatting = AttachmentFileNameFormatter()
        
        public var channelInfoFileSubtitleFormatter: any AttachmentFormatting = ChannelInfoFileSubtitleFormatter()
        
        public var channelInfoVoiceSubtitleFormatter: any AttachmentFormatting = ChannelInfoVoiceSubtitleFormatter()

        public var logDateFormatter: any DateFormatting = LogDateFormatter()
        
        public var messageBodyFormatter: any MessageBodyFormatting = MessageBodyFormatter()
        
        public var channelLastMessageBodyFormatter: any LastMessageBodyFormatting = ChannelLastMessageBodyFormatter()
        
        public var repliedMessageBodyFormatter: any RepliedMessageBodyFormatting = RepliedMessageBodyFormatter()

        /// The one-line preview shown in the pinned messages banner and list.
        public var pinnedMessageBodyFormatter: any PinnedMessageBodyFormatting = PinnedMessageBodyFormatter()
        
        public var editMessageBodyFormatter: any EditMessageBodyFormatting = EditMessageBodyFormatter()
        
        public var replyMessageBodyFormatter: any ReplyMessageBodyFormatting = ReplyMessageBodyFormatter()
        
        public var draftMessageBodyFormatter: any DraftMessageBodyFormatting = DraftMessageBodyFormatter()
        
        public var channelEventTitleFormatter: any ChannelEventTitleFormatting = ChannelEventTitleFormatter()

        public var voteCountFormatter: any VoteCountFormatting = VoteCountFormatter()

        public var voterDateFormatter: any DateFormatting = VoterDateFormatter()

        public var pollTypeFormatter: any PollTypeFormatting = PollTypeFormatter()
        
        public var unsupportedMessageFormatter: any UnsupportedMessageFormatting = UnsupportedMessageFormatter()

        public var unsupportedMessageShortFormatter: any UnsupportedMessageShortFormatting = UnsupportedMessageShortFormatter()

        public var systemMessageBodyFormatter: any SystemMessageBodyFormatting = SystemMessageBodyFormatter()

        public init() {}
    }
}
