//
//  InputRouter.swift
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

open class InputRouter: Router<MessageInputViewController> {
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
        rootViewController.showBottomSheet(actions: actions)
    }

    open func showPhotos(selectedPhotoAssetIdentifiers: Set<String>? = nil,
                         callback: @escaping ([PHAsset], MediaPickerViewController) -> Bool)
    {
        guard rootViewController.selectedMediaView.items.count < SceytChatUIKit.shared.config.attachmentSelectionLimit else {
            showAlert(message: L10n.Error.max20Items)
            return
        }
        let picker = Components.mediaPickerViewController.init(
            selectedAssetIdentifiers: selectedPhotoAssetIdentifiers,
            attachmentSelectionLimit: SceytChatUIKit.shared.config.attachmentSelectionLimit - rootViewController.selectedMediaView.items.count + (selectedPhotoAssetIdentifiers?.count ?? 0)
        )
        picker.onSelected = callback
        let nav = Components.navigationController.init()
        nav.viewControllers = [picker]
        rootViewController.present(nav, animated: true)
    }

    open func showDocuments(callback: @escaping ([URL]) -> Void) {
        guard rootViewController.selectedMediaView.items.count < SceytChatUIKit.shared.config.attachmentSelectionLimit else {
            showAlert(message: L10n.Error.max20Items)
            return
        }
        DocumentPickerController(presenter: self.rootViewController)
            .showPicker(callback: callback)
    }

    open func showCamera(callback: @escaping (AttachmentModel?) -> Void) {
        guard rootViewController.selectedMediaView.items.count < SceytChatUIKit.shared.config.attachmentSelectionLimit else {
            showAlert(message: L10n.Error.max20Items)
            return
        }
        ImagePickerController(presenter: self.rootViewController)
            .showCamera(callback: callback)
    }
}
