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
    
    open lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    public func format(_ attachment: ChatMessage.Attachment) -> String {
        return dateFormatter.string(from: attachment.createdAt)
    }
}
