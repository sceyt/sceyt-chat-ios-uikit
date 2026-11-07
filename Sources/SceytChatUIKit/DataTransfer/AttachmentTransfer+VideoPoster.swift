//
//  AttachmentTransfer+VideoPoster.swift
//  SceytChatUIKit
//
//  What a video's poster leaves in the attachment's metadata. The poster transfer itself is
//  `VideoPosterTransfer`.
//

import Foundation
import SceytChat
import UIKit.UIImage

extension AttachmentTransfer {
    /// Sets `atch`'s metadata to `meta`, keeping the keys the typed model does not know (a
    /// provider's entries): a dedupe hit's metadata already carries the reused object's.
    static func updateMetadata(of atch: ChatMessage.Attachment, rebuiltFrom meta: ChatMessage.Attachment.Metadata<String>) {
        atch.updateMetadata(ChatMessage.Attachment.metadata(meta.build(), preservingUnownedKeysFrom: atch.metadata))
    }

    /// Writes a downloaded poster to the cache.
    static func storeVideoThumbnail(_ localUrl: URL, of attachment: ChatMessage.Attachment, at destination: URL) throws {
        try VideoPosterTransfer.store(localUrl, of: attachment, at: destination)
    }
}
