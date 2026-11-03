//
//  AttachmentKeyProvider.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

public enum EncryptionRequirement {
    /// Plaintext: the legacy path, unchanged.
    case none
    /// Must leave the device encrypted. If anything in the chain cannot do that, the
    /// transfer fails instead of sending plaintext.
    case required
}

/// The encryption policy. Keys are the Chat SDK's: `FileEncryptionProvider.prepareUpload`
/// makes a new one per upload, and it travels in the attachment's metadata. The host sets
/// `Components.attachmentKeyProvider`.
public protocol AttachmentKeyProvider: AnyObject {
    /// Whether this attachment must be encrypted on upload.
    func requirement(for attachment: ChatMessage.Attachment, in message: ChatMessage) -> EncryptionRequirement
}

/// The key travels inside the message metadata. Ships with encryption off.
open class InlineAttachmentKeyProvider: AttachmentKeyProvider {

    public let requirement: (ChatMessage.Attachment, ChatMessage) -> EncryptionRequirement

    public init(requirement: @escaping (ChatMessage.Attachment, ChatMessage) -> EncryptionRequirement = { _, _ in .none }) {
        self.requirement = requirement
    }

    open func requirement(for attachment: ChatMessage.Attachment, in message: ChatMessage) -> EncryptionRequirement {
        guard attachment.type != "link" else { return .none }
        let decided = self.requirement(attachment, message)
        logger.debug("[Encryption] \(TransferLog.currentTag) requirement \(decided) for \(attachment.transferLogDescription) message tid=\(message.tid)")
        return decided
    }
}
