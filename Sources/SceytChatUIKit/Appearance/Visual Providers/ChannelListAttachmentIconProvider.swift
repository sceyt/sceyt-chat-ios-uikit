//
//  ChannelListAttachmentIconProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct ChannelListAttachmentIconProvider: AttachmentIconProviding {
    public func provideVisual(for attachment: ChatMessage.Attachment) -> UIImage? {
        switch attachment.type {
        case "file":
            return .attachmentFile
        case "image":
            return .attachmentImage
        case "video":
            return .attachmentVideo
        case "voice":
            return .attachmentVoice
        default:
            return nil
        }
    }
}
