//
//  UIImageView+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension UIImageView {
    // Data holder tap recognizer
    private class TapWithDataRecognizer: UITapGestureRecognizer {
        weak var from: UIViewController?
        var previewer: (() -> PreviewDataSource?)?
        var item: PreviewItem?
        var viewOnce: Bool = false
        var messageText: String?
    }
    
    private var viewController: UIViewController? {
        guard let rootViewController = window?.rootViewController
        else { return nil }
        return rootViewController.presentedViewController != nil ? rootViewController.presentedViewController : rootViewController
    }
    
    func setup(
        previewer: (() -> (any PreviewDataSource)?)?,
        item: PreviewItem?,
        from: UIViewController? = nil,
        viewOnce: Bool = false,
        messageText: String? = nil) {
        var _tapRecognizer: TapWithDataRecognizer? = gestureRecognizers?.first(where: { $0 is TapWithDataRecognizer }) as? TapWithDataRecognizer

        isUserInteractionEnabled = true
        clipsToBounds = true

        if _tapRecognizer == nil {
            _tapRecognizer = TapWithDataRecognizer(
                target: self, action: #selector(showImageViewer(_:)))
            _tapRecognizer!.numberOfTouchesRequired = 1
            _tapRecognizer!.numberOfTapsRequired = 1
        }
        // Pass the Data
        _tapRecognizer!.previewer = previewer
        _tapRecognizer!.item = item
        _tapRecognizer!.from = from
        _tapRecognizer!.viewOnce = viewOnce
        _tapRecognizer!.messageText = messageText
        addGestureRecognizer(_tapRecognizer!)
    }
    
    @objc
    private func showImageViewer(_ sender: TapWithDataRecognizer) {
        guard let sourceView = sender.view as? UIImageView else { return }
        logThumbnailStateOnPreviewTap(sourceView: sourceView, item: sender.item, viewOnce: sender.viewOnce)
        UIApplication.shared.sendAction(#selector(resignFirstResponder), to: nil, from: nil, for: nil)

        // For view-once messages, create a single-item previewer with just the pressed item
        let finalPreviewer: PreviewDataSource
        let initialIndex: Int

        if sender.viewOnce, let item = sender.item {
            let attachment = item.attachment

            if attachment.status == .done || fileProvider.filePath(attachment: attachment) != nil {
                // file is fully on disk (covers stuck .downloading case too)
                finalPreviewer = SingleItemPreviewDataSource(item: item)
                initialIndex = 0
            } else {
                // genuinely still downloading — retry to unstick and wait
                let message = try? DataProvider.database.read {
                    MessageDTO.fetch(id: attachment.messageId, context: $0)?.convert()
                }.get()
                guard let message else { return }
                fileProvider.downloadMessageAttachmentsIfNeeded(message: message, attachments: [attachment]) { [weak self] _, _ in
                    // re-trigger tap after download completes
                }
                return
            }
        } else {
            if let item = sender.item {
                let attachment = item.attachment
                if fileProvider.filePath(attachment: attachment) != nil {
                    if attachment.status != .done {
                        attachment.status = .done
                        DataProvider.database.write {
                            AttachmentDTO.fetch(id: attachment.id, context: $0)?.status = ChatMessage.Attachment.TransferStatus.done.rawValue
                        } completion: { error in
                            logger.errorIfNotNil(error, "")
                        }
                    }
                } else if attachment.status != .done {
                    logger.verbose("[Attachment] showImageViewer blocked — attachment not downloaded yet, status=\(attachment.status) id=\(attachment.id)")
                    return
                }
            }
            guard let previewer = sender.previewer?(),
                  previewer.canShowPreviewer()
            else { return }
            finalPreviewer = previewer
            initialIndex = sender.item.flatMap { previewer.indexOfItem($0) } ?? 0
        }

        let imageCarousel = Components.mediaPreviewerCarouselViewController.init(
                sourceView: sourceView,
                previewDataSource: finalPreviewer,
                initialIndex: initialIndex,
                viewOnce: sender.viewOnce,
                messageText: sender.messageText)
        let presentFromViewController = sender.from ?? viewController
        presentFromViewController?.present(Components.mediaPreviewerNavigationController.init(imageCarousel), animated: true)
    }

    /// Diagnostic for the "image/video download finished but the cell stayed on the blurry
    /// placeholder" bug (see `project_blurry_thumbnail_stays_after_download`). The previewer always
    /// renders the sharp full-resolution file, so opening a preview is the exact moment the user
    /// sees the discrepancy the bug produces: cell blurry, preview sharp. We snapshot the relevant
    /// state at tap time so that if the bug ever recurs we have a record of *why* the cell didn't
    /// update, instead of only an after-the-fact "it looked blurry".
    ///
    /// What we capture, keyed by attachment id so it can be correlated with the `[Attachment]`
    /// `data.didSet` / self-heal / `loadThumbnail` logs:
    ///   • the cell's currently displayed image size (a tiny size == still on the thumbHash placeholder),
    ///   • the layout's `isThumbnailLoadedFromFile` flag — the authoritative "did the sharp swap land here"
    ///     signal — when the tapped image lives inside a `MessageCell.AttachmentView`,
    ///   • whether the full file and a sharp thumbnail already exist on disk.
    ///
    /// We log ONLY when the bug is present (sharp thumbnail on disk but the bound layout never
    /// swapped to it) — a healthy tap produces no output. Grep `[BLURFIX]` and follow the attachment
    /// id back through the `[Attachment]` logs to see which path (duplicate layout instance / missed
    /// completion callback / missed reconfigure) skipped this cell. No-op unless warnings are
    /// enabled, and skipped for view-once (its blur is intentional, not this bug).
    private func logThumbnailStateOnPreviewTap(sourceView: UIImageView, item: PreviewItem?, viewOnce: Bool) {
        guard !viewOnce, let attachment = item?.attachment else { return }
        let type = AttachmentType(rawValue: attachment.type)
        guard type == .image || type == .video else { return }

        // The cell's imageView is pinned directly inside its AttachmentView, so the superview gives
        // us the bound layout — and with it the authoritative isThumbnailLoadedFromFile flag. nil for
        // non message-list previews (e.g. channel-info cells), where we fall back to the on-disk facts.
        let layout = (sourceView.superview as? MessageCell.AttachmentView)?.data
        let displayed = sourceView.image?.size ?? .zero
        let preferred = (layout?.thumbnailSize ?? .zero) == .zero
            ? MessageLayoutModel.defaults.imageAttachmentSize
            : (layout?.thumbnailSize ?? MessageLayoutModel.defaults.imageAttachmentSize)

        let fullFileOnDisk = fileProvider.filePath(attachment: attachment) != nil
        let sharpThumbOnDisk = fileProvider.thumbnailFile(for: attachment, preferred: preferred) != nil
        let mediaReady = attachment.status == .done || fullFileOnDisk
        let loadedFromFile = layout?.isThumbnailLoadedFromFile

        // Authoritative recurrence signal: media is fully available and a sharp thumbnail exists on
        // disk, yet the bound layout never marked itself file-backed → the cell is still blurry.
        // Only log when this holds — a healthy "cell already sharp" tap produces no output.
        guard mediaReady, sharpThumbOnDisk, loadedFromFile == false else { return }

        logger.debug("[BLURFIX] preview-tap BLURRY-CELL RECURRENCE: sharp thumbnail was on disk but the bound layout never swapped to it — "
            + "id=\(attachment.id) tid=\(attachment.tid) status=\(attachment.status) "
            + "displayed=\(Int(displayed.width))x\(Int(displayed.height))"
            + "fullFileOnDisk=\(fullFileOnDisk) sharpThumbOnDisk=\(sharpThumbOnDisk) "
            + "isThumbnailLoadedFromFile=\(loadedFromFile.map(String.init(describing:)) ?? "n/a") hasLayout=\(layout != nil)")
    }
}
