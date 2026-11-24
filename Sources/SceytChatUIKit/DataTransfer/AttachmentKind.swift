//
//  AttachmentKind.swift
//  SceytChatUIKit
//
//  The kinds of attachment the transfer layer treats differently, instead of comparing
//  `type` strings at every branch.
//

import Foundation

enum AttachmentKind: Equatable {
    /// Resized before it is sent; its local file must be a readable image.
    case image
    /// Exported before it is sent, and sent with a poster frame.
    case video
    /// Sent as it is (a folder is zipped first).
    case file
    case voice
    /// Nothing to transfer.
    case link
    /// Any other `type`: sent as it is.
    case other(String)

    init(_ type: String) {
        switch type {
        case "image": self = .image
        case "video": self = .video
        case "file": self = .file
        case "voice": self = .voice
        case "link": self = .link
        default: self = .other(type)
        }
    }
}

extension ChatMessage.Attachment {
    var kind: AttachmentKind { AttachmentKind(type) }
}
