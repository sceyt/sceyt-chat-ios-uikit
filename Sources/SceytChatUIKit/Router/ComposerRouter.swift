//
//  ComposerRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Photos
import UIKit

public enum AttachmentPickerSource {
    case camera
    case media
    case file
}

open class ComposerRouter: Router<ComposerVC> {
    func showAttachmentAlert(sources: [AttachmentPickerSource], sourceView: UIView?, callback: @escaping (AttachmentPickerSource?) -> Void) {
        var actions = [SheetAction]()
        if sources.contains(.camera) {
            actions.append(.init(
                title: L10n.Alert.Button.openCamera,
                icon: .chatActionCamera,
                style: .default
            ) { callback(.camera) })
        }
        if sources.contains(.media) {
            actions.append(.init(
                title: L10n.Alert.Button.openGallery,
                icon: .chatActionGallery,
                style: .default
            ) { callback(.media) })
        }
        if sources.contains(.file) {
            actions.append(.init(
                title: L10n.Alert.Button.openFiles,
                icon: .chatActionFile,
                style: .default
            ) { callback(.file) })
        }
        actions.append(.init(
            title: L10n.Alert.Button.cancel,
            style: .cancel
        ) { callback(nil) })
        rootVC.showBottomSheet(actions: actions)
    }

    open func showPhotos(selectedPhotoAssetIdentifiers: Set<String>? = nil,
                         callback: @escaping ([PHAsset], PhotosPickerVC) -> Bool)
    {
        guard rootVC.mediaView.items.count < SceytChatUIKit.shared.config.maximumAttachmentsAllowed else {
            showAlert(message: L10n.Error.max20Items)
            return
        }
        let picker = Components.imagePickerVC.init(
            selectedAssetIdentifiers: selectedPhotoAssetIdentifiers,
            maximumAttachmentsAllowed: SceytChatUIKit.shared.config.maximumAttachmentsAllowed - rootVC.mediaView.items.count + (selectedPhotoAssetIdentifiers?.count ?? 0)
        )
        picker.onSelected = callback
        let nav = Components.navigationController.init()
        nav.viewControllers = [picker]
        rootVC.present(nav, animated: true)
    }

    open func showDocuments(callback: @escaping ([URL]) -> Void) {
        guard rootVC.mediaView.items.count < SceytChatUIKit.shared.config.maximumAttachmentsAllowed else {
            showAlert(message: L10n.Error.max20Items)
            return
        }
        DocumentPickerController(presenter: self.rootVC)
            .showPicker(callback: callback)
    }

    open func showCamera(callback: @escaping (AttachmentView?) -> Void) {
        guard rootVC.mediaView.items.count < SceytChatUIKit.shared.config.maximumAttachmentsAllowed else {
            showAlert(message: L10n.Error.max20Items)
            return
        }
        ImagePickerController(presenter: self.rootVC)
            .showCamera(callback: callback)
    }
}
