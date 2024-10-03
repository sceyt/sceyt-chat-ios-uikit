//
//  ChannelInfoVoiceSubtitleFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class ChannelInfoVoiceSubtitleFormatter: AttachmentFormatting {
    
    public init() {}
    
    public func format(_ attachment: ChatMessage.Attachment) -> String {
        SceytChatUIKit.shared.formatters.channelInfoAttachmentDateFormatter.format(attachment.createdAt)
    }
}
