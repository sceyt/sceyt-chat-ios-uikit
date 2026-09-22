//
//  AttachmentTransferStatusRelay.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation

public protocol AttachmentTransferStatusObserver: AnyObject {
    /// Called on the main thread whenever an attachment's transfer status changes *outside*
    /// the progress/completion stream — a pause, a resume, or a failure, raised from any
    /// screen. Observers decide relevance by comparing transfer identity against their
    /// currently bound attachment.
    func attachmentTransferStatusDidChange(
        _ attachment: ChatMessage.Attachment,
        status: ChatMessage.Attachment.TransferStatus
    )
}

/// Instance-agnostic delivery of pause/resume/failure status changes to live views.
///
/// `AttachmentTransfer.stopTransfer` / `resumeTransfer` flip `attachment.status`, persist it,
/// and drive the task — but they publish nothing into the progress observer cache, which is
/// fanned out only from `onProgress` / `onCompletion`. `SCTDataSessionTaskInfo.stop()` and
/// `resume()` likewise fire `onAction` (transport-facing), never `onEvent`. So a view holding
/// a live progress subscription hears nothing at all when the transfer is paused.
///
/// The remaining route was a cell reconfigure, and that does not happen either: a status-only
/// change leaves `MessageLayoutModel.updateOptions` empty, so `contentVersion` never bumps and
/// the snapshot diff produces no reload. The layout model *is* updated in place, which is why
/// scrolling the cell out of view and back shows the correct state while the visible cell
/// stays stale — the exact symptom this relay exists to remove.
///
/// Mirrors `AttachmentSharpThumbnailRelay`: weak membership, keyed by attachment identity
/// rather than by layout instance, so any live view showing that attachment can heal no matter
/// which screen raised the change or which duplicate `AttachmentLayout` instance it holds.
/// Main-thread only.
public final class AttachmentTransferStatusRelay {
    public static let `default` = AttachmentTransferStatusRelay()

    private let observers = NSHashTable<AnyObject>.weakObjects()

    public func add(_ observer: AttachmentTransferStatusObserver) {
        observers.add(observer)
    }

    /// Announces `status` for `attachment`. Safe to call from any queue — the fan-out is
    /// hopped to main, where every observer's UI work belongs.
    public func post(
        _ attachment: ChatMessage.Attachment,
        status: ChatMessage.Attachment.TransferStatus
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.post(attachment, status: status)
            }
            return
        }
        logger.verbose("[Attachment] status relay post \(status) for \(AttachmentTransfer.transferIdentity(of: attachment))")
        // allObjects snapshots the live observers, so a handler that triggers a nested post
        // re-enters safely. Note that reading a weak table retains+autoreleases the members —
        // observers may outlive their last strong reference until the enclosing pool drains.
        for case let observer as AttachmentTransferStatusObserver in observers.allObjects {
            observer.attachmentTransferStatusDidChange(attachment, status: status)
        }
    }
}
