//
//  ChannelInfoFileSubtitleFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 02.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class ChannelInfoFileSubtitleFormatter: AttachmentFormatting {
    
    public init() {}
    
    public func format(_ attachment: ChatMessage.Attachment) -> String {
        SceytChatUIKit.shared.formatters.attachmentSizeFormatter.format(UInt64(attachment.uploadedFileSize)) + " • " + SceytChatUIKit.shared.formatters.channelInfoAttachmentDateFormatter.format(attachment.createdAt)
    }
}
