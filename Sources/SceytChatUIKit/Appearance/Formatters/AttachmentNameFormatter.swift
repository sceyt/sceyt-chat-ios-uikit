//
//  AttachmentNameFormatter.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

open class AttachmentNameFormatter: AttachmentFormatting {
    
    public init() {}
    
    public func format(_ attachment: ChatMessage.Attachment) -> String {
        switch attachment.type {
        case "file":
            return L10n.Message.Attachment.file
        case "image":
            return L10n.Message.Attachment.image
        case "video":
            return L10n.Message.Attachment.video
        case "voice":
            return L10n.Message.Attachment.voice
        case "link":
            return L10n.Message.Attachment.link
        default:
            return ""
        }
    }
}
