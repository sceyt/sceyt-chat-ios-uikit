//
//  CaptureRouter.swift
//  SceytChatUIKit
//

import UIKit
import MobileCoreServices

extension Router {
    
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
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if let popoverPresentationController = alert.popoverPresentationController,
           let sourceView = sourceView
        {
            popoverPresentationController.sourceView = sourceView
            popoverPresentationController.sourceRect = .init(origin: sourceView.bounds.center, size: .zero)
        }
        if types.contains(.camera) {
            let cameraAction = UIAlertAction(
                title: L10n.Capture.takePhoto,
                style: .default
            ) { _ in
                action(.camera)
            }
            alert.addAction(cameraAction)
        }
        if types.contains(.photoLibrary) {
            let photoAction = UIAlertAction(
                title: L10n.Capture.selectPhoto,
                style: .default
            ) { _ in
                action(.photoLibrary)
            }
            alert.addAction(photoAction)
            
           
        }
        if types.contains(.delete) {
            let deleteAction = UIAlertAction(
                title: L10n.Alert.Button.delete,
                style: .default
            ) { _ in
                action(.delete)
            }
            alert.addAction(deleteAction)
        }
        
        let cancelAction = UIAlertAction(
            title: L10n.Alert.Button.cancel,
            style: .cancel,
            handler: { _ in
                action(.none)
            })
        alert.addAction(cancelAction)
        
        rootVC.present(alert, animated: true)
    }
    
    func showCamera(mediaTypes: [MediaType] = [.image, .video, .movie], done: @escaping (AttachmentView?) -> Void) {
        ImagePickerController(presenter: rootVC)
            .showCamera(mediaTypes: mediaTypes.map { $0.rawValue }, callback: done)
    }
    
    func selectPhoto(mediaTypes: [MediaType] = [.image, .video, .movie], done: @escaping (AttachmentView?) -> Void) {
        ImagePickerController(presenter: rootVC)
            .showPhotoLibrary(mediaTypes: mediaTypes.map { $0.rawValue }, callback: done)
    }
    
    func editImage(_ image: UIImage, done: @escaping (UIImage?) -> Void) {
        done(image)
//        ImagePicker(presenter: rootVC)
//            .edit(image: image) { edit in
//                done(edit?.image)
//            }
    }
}
