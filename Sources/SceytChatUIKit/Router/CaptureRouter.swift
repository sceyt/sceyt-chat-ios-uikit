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
        rootViewController.showBottomSheet(actions: actions)
    }
    
    func showCamera(mediaTypes: [MediaType] = [.image, .video, .movie], done: @escaping (AttachmentModel?) -> Void) {
        ImagePickerController(presenter: rootViewController)
            .showCamera(mediaTypes: mediaTypes.map { $0.rawValue }, callback: done)
    }
    
    func selectPhoto(mediaTypes: [MediaType] = [.image, .video, .movie], done: @escaping (AttachmentModel?) -> Void) {
        ImagePickerController(presenter: rootViewController)
            .showPhotoLibrary(mediaTypes: mediaTypes.map { $0.rawValue }, callback: done)
    }
    
    func editImage(_ image: UIImage, appearance: ImageCropperViewController.Appearance? = nil, done: @escaping (UIImage) -> Void) {
        let viewController = Components.imageCropperViewController.init(
            onComplete: { [weak self] edited in
                guard let self else { return }
                done(edited)
                self.dismiss()
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )
        viewController.parentAppearance = appearance
        viewController.viewModel = Components.imageCropperViewModel.init(image: image)
        let nav = Components.navigationController.init()
        nav.viewControllers = [viewController]
        nav.modalPresentationStyle = .fullScreen
        rootViewController.present(nav, animated: true)
    }
}
