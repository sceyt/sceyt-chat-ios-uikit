//
//  AttachmentTransfer+Reconcile.swift
//  SceytChatUIKit
//
//  What a cell bind does: the attachment's status is reconciled with what is on disk, and the
//  downloads still needed are started.
//

import Foundation
import UIKit

extension AttachmentTransfer {
    /// Statuses that describe a download either in flight or waiting for one, and are
    /// therefore safe to reconcile to `.done` when the bytes turn out to be on disk.
    ///
    /// Deliberately excludes every upload status: an upload has a local file from the
    /// start — that file is what is being sent — so "the file exists" says nothing about
    /// whether it was delivered. `.pending` is shared by both directions, and is included
    /// because that is the one combination the reconcile has always covered.
    static let healableDownloadStatuses: Set<ChatMessage.Attachment.TransferStatus> = [
        .pending, .downloading, .pauseDownloading, .failedDownloading
    ]

    /// Statuses only an upload has.
    static let uploadStatuses: Set<ChatMessage.Attachment.TransferStatus> = [
        .uploading, .pauseUploading, .failedUploading
    ]

    /// An outgoing attachment whose bytes have not been uploaded: there is nothing to download,
    /// and a download attempt would fail it as `.failedDownloading` (a download button on a
    /// file that was never sent). No url, and either it is the sender's (`tid`), it is in an
    /// upload status, or its source file is set. Its source file may not exist yet (a picked
    /// video is still being copied), so `isPendingUpload` alone does not cover it.
    static func isAwaitingUpload(_ attachment: ChatMessage.Attachment) -> Bool {
        guard (attachment.url ?? "").isEmpty else { return false }
        return attachment.tid != 0
            || uploadStatuses.contains(attachment.status)
            || attachment.isPendingUpload
    }

    /// Image files already found readable, so a cell bind does not reread a header it has read.
    nonisolated(unsafe) private static let readableImageFiles = NSCache<NSString, NSNumber>()

    /// Paths already removed once this session. A file that is still unreadable after its
    /// re-download is a real file ImageIO cannot decode, not a leftover, and removing it again
    /// would download it on every cell bind.
    nonisolated(unsafe) private static let discardedImageFiles = NSCache<NSString, NSNumber>()

    /// Whether the local file of an image attachment can stand in for its download.
    ///
    /// A failed download can leave something other than the image at the destination — S3
    /// writes its error body there on a 404. Read as "the file is on disk", that marked the
    /// attachment `.done` with bytes nothing can show, and it was never downloaded again. Such a
    /// file is removed so the attachment counts as not downloaded.
    ///
    /// Only finished, received images are judged: a live transfer still owns its file, and an
    /// unsent attachment's file is the user's source, which is never deleted.
    func keepsLocalFile(
        _ path: String,
        of attachment: ChatMessage.Attachment,
        message: ChatMessage
    ) -> Bool {
        guard attachment.kind == .image,
              !attachment.isPendingUpload,
              taskFor(message: message, attachment: attachment) == nil
        else { return true }
        if Self.readableImageFiles.object(forKey: path as NSString) != nil {
            return true
        }
        guard SCTSession.isCompleteImageFile(at: path) else {
            guard Self.discardedImageFiles.object(forKey: path as NSString) == nil else {
                logger.warn("[Attachment] keeping a local image that is still not readable after a re-download \(attachment.transferLogDescription)")
                return true
            }
            Self.discardedImageFiles.setObject(true, forKey: path as NSString)
            logger.error("[Attachment] removing a local image that is not readable, so the download is not done \(attachment.transferLogDescription)")
            TransferLog.remove(URL(fileURLWithPath: path), what: "the unreadable image", context: "[Attachment] \(TransferLog.currentTag)")
            if attachment.filePath == path {
                attachment.filePath = nil
            }
            return false
        }
        Self.readableImageFiles.setObject(true, forKey: path as NSString)
        return true
    }

    func reconcileAndDownload(
        message: ChatMessage,
        attachments: [ChatMessage.Attachment],
        completion: ((ChatMessage?, Error?) -> Void)?
    ) -> [ChatMessage.Attachment] {

        // Before any status filtering: fetch the small "video_thumb" posters for
        // videos that aren't local yet, so even paused/failed video downloads show
        // a sharp preview instead of the blurred thumbHash.
        downloadVideoThumbnailsIfNeeded(message: message, attachments: attachments)

        var reconciled = [ChatMessage.Attachment]()
        for att in attachments where att.kind != .link {
            if Self.isAwaitingUpload(att),
               [.downloading, .pauseDownloading, .failedDownloading].contains(att.status),
               taskFor(message: message, attachment: att) == nil {
                // A download status on a file that was never sent (an earlier bind tried to
                // download it): it is an upload waiting to go, not a download button.
                logger.warn("[Attachment] outgoing attachment had download status \(att.status), reset to .pending \(att.transferLogDescription)")
                att.status = .pending
                att.transferProgress = 0
                reconciled.append(att)
                AttachmentTransferStatusRelay.default.post(att, status: .pending)
                continue
            }
            let resolvedLocalFilePath = dataSession(for: message)?.getFilePath(attachment: att)
            if let filePath = resolvedLocalFilePath, !filePath.isEmpty,
               keepsLocalFile(filePath, of: att, message: message) {
                guard Self.healableDownloadStatuses.contains(att.status),
                      // `.pending` is shared by both directions and this rule reads a local
                      // file as proof the transfer finished — true for a download, false for
                      // an upload whose source file is exactly what has not been sent yet.
                      // Without this an outgoing attachment waiting to upload is marked
                      // `.done` the first time its cell is displayed, which takes the loader
                      // off screen and makes an unsent photo look delivered.
                      !att.isPendingUpload,
                      taskFor(message: message, attachment: att) == nil
                else { continue }
                logger.verbose("[Attachment] reconciling stale \(att.status) to .done, file is on disk \(att.transferLogDescription)")
                att.status = .done
                att.transferProgress = 1
                if att.filePath != filePath {
                    att.filePath = filePath
                }
                reconciled.append(att)

                let key = Self.key(message: message, attachment: att)
                logger.verbose("[Attachment] onCompletion KEY \(TransferLog.redact(key))")
                let attachmentCompletion = AttachmentCompletion(message: message, attachment: att, error: nil)
                observers.completionObservers(forKey: key).forEach { $0(attachmentCompletion) }
                AttachmentTransferStatusRelay.default.post(att, status: .done)
            } else if att.status == .done {
                att.status = .pending
                att.transferProgress = 0
                reconciled.append(att)
            }
        }
        if !reconciled.isEmpty {
            store.save(reconciled, of: message)
        }

        let needsToDownloadAttachments = attachments.filter {
            $0.kind != .link &&
            // An unsent attachment's missing file is not a download to start: its upload
            // owns it (a picked video is still being copied when the cell first binds).
            !Self.isAwaitingUpload($0) &&
            !Self.uploadStatuses.contains($0.status) &&
            $0.status != .pauseDownloading &&
            $0.status != .failedDownloading &&
            $0.status != .done &&
            dataSession(for: message)?.getFilePath(attachment: $0) == nil
        }
        
        guard !needsToDownloadAttachments.isEmpty else {
            completion?(message, nil)
            return []
        }
        // Already on the transfer queue: started here, not queued behind other work.
        startDownloads(message: message, attachments: needsToDownloadAttachments, completion: completion)
        return needsToDownloadAttachments
    }
}
