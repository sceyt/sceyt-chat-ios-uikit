//
//  AttachmentPickerRouter.swift
//  SceytChatUIKit
//

import UIKit

public extension Router {

//    func openAttachmentPicker(sources: [AttachmentPickerSource], sourceView: UIView?, callback: @escaping (PickedData?) -> Void) {
//
//        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
//        if let popoverPresentationController = alert.popoverPresentationController, let sourceView = sourceView {
//            popoverPresentationController.sourceView = sourceView
//            popoverPresentationController.sourceRect = .init(origin: sourceView.center, size: .zero)
//        }
//        if UIImagePickerController.isSourceTypeAvailable(.camera), sources.contains(.camera) {
//            alert.addAction(UIAlertAction(title: L10n.Alert.Button.openCamera, style: .default, handler: { (_) in
//                ImagePickerController(presenter: self.rootVC)
//                    .showCamera(callback: callback)
//            }))
//        }
////        if sources.contains(.media) {
////            alert.addAction(UIAlertAction(title: L10n.Alert.Button.openGallery, style: .default, handler: { (_) in
////                let nav = UINavigationController(rootViewController: PhotosPickerVC())
////                self.rootVC.present(nav, animated: true)
//////                ImagePickerController(presenter: self.rootVC)
//////                    .showPhotoLibrary(callback: callback)
////            }))
////        }
////        if sources.contains(.file) {
////            alert.addAction(UIAlertAction(title: L10n.Alert.Button.openFiles, style: .default, handler: { (_) in
////                DocumentPickerController.init(presenter: self.rootVC)
////                    .showPicker(callback: callback)
////            }))
////        }
//
//        alert.addAction(UIAlertAction(title: L10n.Alert.Button.cancel, style: .cancel, handler: { (_) in
//            callback(nil)
//        }))
//        rootVC.present(alert, animated: true)
//    }
}
