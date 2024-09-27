//
//  AttachmentIconProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct AttachmentIconProvider: AttachmentIconProviding {
    public func provideVisual(for attachment: ChatMessage.Attachment) -> UIImage? {
        switch attachment.type {
        case "file":
            return .messageFile
        case "image":
            return nil
        case "video":
            return nil
        case "voice":
            return .audioPlayerMic
        case "link":
            return .link
        default:
            return nil
        }
    }
}
