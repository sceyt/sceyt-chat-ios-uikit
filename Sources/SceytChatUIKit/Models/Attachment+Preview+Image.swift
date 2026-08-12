//
//  Attachment+Preview+Image.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension ChatMessage.Attachment {
    
    var originalImage: UIImage? {
        if let filePath,
            let image = UIImage(contentsOfFile: filePath) {
            return image
        }
        return thumbnailImage
    }
    
    var thumbnailImage: UIImage? {
        guard let path = fileProvider.thumbnailFile(for: self, preferred: MessageLayoutModel.defaults.imageAttachmentSize)
        else {
            if let image = imageDecodedMetadata?.thumbnailImage {
                return image
            } else if let thumbnail = imageDecodedMetadata?.thumbnail,
                      let image = Components.imageBuilder.image(from: thumbnail)
            {
                return image
            }
            return nil
        }
        return UIImage(contentsOfFile: path)
    }

    /// Preview for a document attachment — an image or a video sent as a file. Resolved the
    /// same way the file bubble paints its icon slot (`AttachmentLayout.loadThumbnail`): the
    /// sharp on-disk thumbnail first, then the blurred thumbHash carried in metadata.
    ///
    /// `nil` for a document that has no preview at all (pdf/zip/…) and for a previewable one
    /// that is not on disk yet and whose sender shipped no thumbHash — callers fall back to
    /// the generic file icon there.
    var filePreviewImage: UIImage? {
        let fileName = name ?? ((url ?? filePath) as NSString?)?.lastPathComponent
        guard AttachmentFileKind.kind(ofFileNamed: fileName).isPreviewable
        else { return nil }

        if let path = fileProvider.thumbnailFile(for: self, preferred: MessageLayoutModel.defaults.imageAttachmentSize),
           let image = UIImage(contentsOfFile: path)
        {
            return image
        }
        if let image = imageDecodedMetadata?.thumbnailImage {
            return image
        }
        if let thumbnail = imageDecodedMetadata?.thumbnail {
            // thumbHash is what the file attachments ship today; the base64 form is the
            // legacy encoding older senders used for the same field.
            return Components.imageBuilder.image(thumbHash: thumbnail)
                ?? Components.imageBuilder.image(from: thumbnail)
        }
        return nil
    }

    /// True when this document is a video sent as a file, i.e. its preview deserves a play badge.
    var isVideoFileAttachment: Bool {
        let fileName = name ?? ((url ?? filePath) as NSString?)?.lastPathComponent
        return AttachmentFileKind.kind(ofFileNamed: fileName).isVideo
    }
}
