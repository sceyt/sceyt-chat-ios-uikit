//
//  CaptureRouter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import MobileCoreServices
import UIKit

public extension Router {
    enum CaptureType: String {
        case camera
        case photoLibrary
        case delete
        case none
    }
    
    enum MediaType: String {
        case image
        case video
        case movie
        
        public var rawValue: String {
            switch self {
            case .image:
                return String(kUTTypeImage)
            case .video:
                return String(kUTTypeVideo)
            case .movie:
                return String(kUTTypeMovie)
            }
        }
    }
    
    func showCaptureAlert(types: [CaptureType], sourceView: UIView? = nil, _ action: @escaping (CaptureType) -> Void) {
        var actions = [SheetAction]()
        if types.contains(.camera) {
            actions.append(.init(
                title: L10n.Capture.takePhoto,
                icon: .chatActionCamera,
                style: .default
            ) { action(.camera) })
        }
        if types.contains(.photoLibrary) {
            actions.append(.init(
                title: L10n.Capture.selectPhoto,
                icon: .chatActionGallery,
                style: .default
            ) { action(.photoLibrary) })
        }
        if types.contains(.delete) {
            actions.append(.init(
                title: L10n.Alert.Button.delete,
                icon: .chatDelete,
                style: .destructive
            ) { action(.delete) })
        }
        actions.append(.init(
            title: L10n.Alert.Button.cancel,
            style: .cancel
        ) { action(.none) })
        rootVC.showBottomSheet(actions: actions)
    }
    
    func showCamera(mediaTypes: [MediaType] = [.image, .video, .movie], done: @escaping (AttachmentView?) -> Void) {
        ImagePickerController(presenter: rootVC)
            .showCamera(mediaTypes: mediaTypes.map { $0.rawValue }, callback: done)
    }
    
    func selectPhoto(mediaTypes: [MediaType] = [.image, .video, .movie], done: @escaping (AttachmentView?) -> Void) {
        ImagePickerController(presenter: rootVC)
            .showPhotoLibrary(mediaTypes: mediaTypes.map { $0.rawValue }, callback: done)
    }
    
    func editImage(_ image: UIImage, done: @escaping (UIImage) -> Void) {
        let vc = Components.imageCropperVC.init(
            onComplete: { [weak self] edited in
                guard let self else { return }
                done(edited)
                self.dismiss()
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )
        vc.viewModel = Components.imageCropperVM.init(image: image)
        let nav = Components.navigationController.init()
        nav.viewControllers = [vc]
        nav.modalPresentationStyle = .fullScreen
        rootVC.present(nav, animated: true)
    }
}
