//
//  ComposerRouter.swift
//  SceytChatUIKit
//

import UIKit
import Photos

public enum AttachmentPickerSource {
    case camera
    case media
    case file
}

open class ComposerRouter: Router<ComposerVC> {
    
    func showAttachmentAlert(sources: [AttachmentPickerSource], sourceView: UIView?, callback: @escaping (AttachmentPickerSource?) -> Void) {

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if let popoverPresentationController = alert.popoverPresentationController, let sourceView = sourceView {
            popoverPresentationController.sourceView = sourceView
            popoverPresentationController.sourceRect = .init(origin: sourceView.center, size: .zero)
        }
        if sources.contains(.camera) {
            alert.addAction(UIAlertAction(title: L10n.Alert.Button.openCamera, style: .default, handler: { (_) in
                callback(.camera)
            }))
        }
        if sources.contains(.media) {
            alert.addAction(UIAlertAction(title: L10n.Alert.Button.openGallery, style: .default, handler: { (_) in
                callback(.media)
            }))
        }
        if sources.contains(.file) {
            alert.addAction(UIAlertAction(title: L10n.Alert.Button.openFiles, style: .default, handler: { (_) in
                callback(.file)
            }))
        }

        alert.addAction(UIAlertAction(title: L10n.Alert.Button.cancel, style: .cancel, handler: { (_) in
            callback(nil)
        }))
        rootVC.present(alert, animated: true)
    }
    
    open func showPhotos(selectedPhotoAssetIdentifiers: Set<String>? = nil,
                         callback: @escaping ([PHAsset]?) -> Void) {
        let picker = PhotosPickerVC(selectedAssetIdentifiers: selectedPhotoAssetIdentifiers)
        picker.onSelected = callback
        let nav = UINavigationController(rootViewController: picker)
        rootVC.present(nav, animated: true)
    }
    
    open func showDocuments(callback: @escaping ([URL]) -> Void) {
        DocumentPickerController.init(presenter: self.rootVC)
            .showPicker(callback: callback)

    }
    
    open func showCamera(callback: @escaping (AttachmentView?) -> Void) {
        ImagePickerController(presenter: self.rootVC)
            .showCamera(callback: callback)
    }
}



