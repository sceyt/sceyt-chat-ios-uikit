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
    /// Sets `atch`'s metadata to `meta`, keeping the `enc` the typed model does not know: a
    /// dedupe hit's metadata already carries the reused object's key.
    static func updateMetadata(of atch: ChatMessage.Attachment, rebuiltFrom meta: ChatMessage.Attachment.Metadata<String>) {
        atch.updateMetadata(ChatMessage.Attachment.metadata(meta.build(), preservingEncryptionFrom: atch.metadata))
    }

    /// The `enc` an upload's metadata must carry, or nil when it has none to write: the
    /// uploaded object's key with the poster's rendition, or, for a dedupe hit (nothing was
    /// uploaded, the reused object's `enc` is already in the metadata), that `enc` with the
    /// rendition of a poster uploaded for it.
    static func uploadEncryption(of taskInfo: SCTDataSessionTaskInfo, attachment atch: ChatMessage.Attachment) -> AttachmentEncryption? {
        let renditions = taskInfo.thumbnailRendition.map { [$0] } ?? []
        if let info = taskInfo.uploadedEncryption {
            return AttachmentEncryption(info: info, renditions: renditions)
        }
        guard let rendition = taskInfo.thumbnailRendition, let reused = atch.encryption else { return nil }
        return AttachmentEncryption(
            algorithm: reused.algorithm,
            attachmentId: reused.attachmentId,
            key: reused.key,
            renditions: reused.renditions.filter { $0.role != rendition.role } + [rendition]
        )
    }

    /// Writes a downloaded poster to the cache: decrypted with its `enc.renditions` entry
    /// when the video is encrypted, as is otherwise.
    static func storeVideoThumbnail(_ localUrl: URL, of attachment: ChatMessage.Attachment, at destination: URL, encryption fileEncryption: FileEncryption) async throws {
        try await VideoPosterTransfer.store(localUrl, of: attachment, at: destination, encryption: fileEncryption)
    }
}
