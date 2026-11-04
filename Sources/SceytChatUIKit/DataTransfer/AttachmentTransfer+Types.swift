//
//  AttachmentTransfer+Types.swift
//  SceytChatUIKit
//
//  The values the transfer hands its observers, and its errors.
//

import Foundation

extension AttachmentTransfer {
    public class AttachmentProgress {
        public let message: ChatMessage
        public let attachment: ChatMessage.Attachment
        public let progress: Double
        
        init(message: ChatMessage,
             attachment: ChatMessage.Attachment,
             progress: Double) {
            self.message = message
            self.attachment = attachment
            self.progress = progress
        }
    }
    
    public class AttachmentCompletion {
        public let message: ChatMessage
        public let attachment: ChatMessage.Attachment
        public let error: Error?
        
        init(message: ChatMessage,
             attachment: ChatMessage.Attachment,
             error: Error? = nil
        ) {
            self.message = message
            self.attachment = attachment
            self.error = error
        }
        
    }
}

enum AttachmentTransferError: Error {
    case alreadyTransferring
    case externalTransferrerNotImplemented
    /// A received attachment without a url: there is nothing to download.
    case missingURL
}

public extension AttachmentTransfer {

    /// A stable identity for one progress subscriber, for `objectIdKey`.
    ///
    /// Derived from the observing object, not from the attachment: an attachment's
    /// `description` embeds `filePath`, which is `nil` while downloading and set
    /// once the bytes land, so a key built from it changes underneath the observer
    /// and neither the replace-on-rebind nor the scoped removal can match it.
    static func observerKey(for object: AnyObject, prefix: String) -> String {
        prefix + "." + String(UInt(bitPattern: ObjectIdentifier(object).hashValue), radix: 16)
    }
}
