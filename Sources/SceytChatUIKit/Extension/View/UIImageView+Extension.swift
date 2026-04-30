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
}
