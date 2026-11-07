//
//  AttachmentTransfer+LocalFiles.swift
//  SceytChatUIKit
//
//  An attachment's local file: its path (repaired when the app container moved), the file a
//  transfer leaves it, and its thumbnail.
//

import Foundation
import UIKit

extension AttachmentTransfer {
    /// `decoded` with the size of the file it now describes.
    static func metadata<Thumbnail: Codable>(
        _ decoded: ChatMessage.Attachment.Metadata<Thumbnail>,
        size: CGSize
    ) -> String? {
        ChatMessage.Attachment.Metadata(
            width: Int(size.width),
            height: Int(size.height),
            thumbnail: decoded.thumbnail,
            duration: decoded.duration,
            description: decoded.description,
            imageUrl: decoded.imageUrl,
            thumbnailUrl: decoded.thumbnailUrl,
            hideLinkDetails: decoded.hideLinkDetails,
            videoThumbnail: decoded.videoThumbnail
        ).build()
    }

    /// The file of `attachment` is now at `url` (prepared for its upload, or downloaded):
    /// the metadata follows the file, and the attachment is persisted.
    func updateLocalFile(
        _ url: URL,
        previousPath filePath: String?,
        attachment atch: ChatMessage.Attachment,
        taskInfo: SCTDataSessionTaskInfo,
        message: ChatMessage
    ) {
        let previousMetadata = atch.metadata
        if let builder = environment.imageBuilder().init(imageUrl: url) {
            if let decodedMetadata = atch.imageDecodedMetadata {
                atch.metadata = Self.metadata(decodedMetadata, size: builder.imageSize)
            } else if let decodedMetadata = atch.voiceDecodedMetadata {
                atch.metadata = Self.metadata(decodedMetadata, size: builder.imageSize)
            }
        }
        // The typed rebuild above only knows the media keys: a provider's entries stay.
        atch.metadata = ChatMessage.Attachment.metadata(atch.metadata, preservingUnownedKeysFrom: previousMetadata)
        atch.name = url.lastPathComponent
        atch.filePath = url.path
        let fileSize = environment.storage().sizeOfItem(at: url)
        // A provider delivers the file as the user sees it (decrypted, if it was encrypted).
        if fileSize > 0 {
            atch.uploadedFileSize = fileSize
        }
        if taskInfo.transferType == .download, fileSize > 0 {
            atch.transferProgress = 1
            atch.status = .done
        }
        taskInfo.attachment = atch
        logger.verbose("[Attachment] \(taskInfo.logTag) local file changed (\(fileSize) B), persisted by \(filePath != nil ? "its previous path" : "the attachment")")
        store.saveLocalFile(of: atch, previousPath: filePath, of: message)
    }

    func filePath(attachment: ChatMessage.Attachment) -> String? {
        guard let dataSession = dataSession(forAttachment: attachment)
        else {
            if attachment.filePath != nil {
                return attachment.filePath
            } else if let url = attachment.url {
                return environment.storage().filePath(for: url)
            }
            return nil
        }
        return dataSession.getFilePath(attachment: attachment)
    }

    func repairAttachmentFilePathIfNeeded(_ attachment: ChatMessage.Attachment, dataSession: SCTDataSession) {
        guard let currentPath = attachment.filePath,
              !FileManager.default.fileExists(atPath: currentPath)
        else { return }
        
        if let recoveredPath = dataSession.getFilePath(attachment: attachment),
           FileManager.default.fileExists(atPath: recoveredPath) {
            attachment.filePath = recoveredPath
            return
        }

        if let temporaryPath = recoverTemporaryPath(for: attachment) {
            attachment.filePath = temporaryPath
        }
    }

    func recoverTemporaryPath(for attachment: ChatMessage.Attachment) -> String? {
        let fileName = attachment.name ?? (attachment.filePath as NSString?)?.lastPathComponent
        guard let fileName, !fileName.isEmpty else { return nil }
        
        let tmpPath = FileManager.default.temporaryDirectory.appendingPathComponent(fileName).path
        guard FileManager.default.fileExists(atPath: tmpPath) else { return nil }
        return tmpPath
    }

    func thumbnailFile(for attachment: ChatMessage.Attachment, preferred size: CGSize) -> String? {
        guard let dataSession = dataSession(forAttachment: attachment)
        else { return nil }
        return dataSession.thumbnailFile(for: attachment, preferred: size)
    }
}
