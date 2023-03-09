//
//  PreviewerRouter.swift
//  SceytChatUIKit
//

import UIKit

open class PreviewerRouter: Router<PreviewerVC> {
    
    public enum ShareOption {
        case saveGallery
        case share
        case cancel
    }

    open func showShareActionSheet(
        previewItem: PreviewItem,
        from barButtonItem: UIBarButtonItem,
        callback: @escaping (ShareOption) -> Void
    ) {
        let isVideo = previewItem.attachment.type == "video"
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.barButtonItem = barButtonItem
            popoverPresentationController.permittedArrowDirections = .up
        }
        alert.addAction(
            UIAlertAction(
                title: isVideo ? L10n.Previewer.saveVideo : L10n.Previewer.savePhoto,
                style: .default
            ) { _ in
                callback(.saveGallery)
            })
        
        alert.addAction(
            UIAlertAction(
                title: isVideo ? L10n.Previewer.shareVideo : L10n.Previewer.sharePhoto,
                style: .default
            ) { _ in
                callback(.share)
            })
        
        alert.addAction(
            UIAlertAction(
                title: L10n.Alert.Button.cancel,
                style: .default
            ) { _ in
                callback(.cancel)
            })
        rootVC.present(alert, animated: true)
    }
}
