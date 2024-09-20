//
//  ImagePickerController.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import AVFoundation
import CoreServices
import Photos
import UIKit

open class ImagePickerController: NSObject,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
{
    open lazy var imagePicker = UIImagePickerController()

    private static var retain: ImagePickerController?

    override init() {
        super.init()
        ImagePickerController.retain = self
    }

    open var callback: ((AttachmentView?) -> Void)?

    open func showCamera(mediaTypes: [String] = [String(kUTTypeImage), String(kUTTypeVideo), String(kUTTypeMovie)], callback: @escaping (AttachmentView?) -> Void) {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            self.callback = callback
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            imagePicker.mediaTypes = mediaTypes
            imagePicker.videoQuality = .typeIFrame960x540
            present()
        } else {
            callback(nil)
        }
    }

    open func showPhotoLibrary(mediaTypes: [String] = [String(kUTTypeImage), String(kUTTypeVideo), String(kUTTypeMovie)], callback: @escaping (AttachmentView?) -> Void) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            self.callback = callback
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.mediaTypes = mediaTypes
            present()
        } else {
            callback(nil)
        }
    }

    public weak var presenter: UIViewController?
    public init(presenter: UIViewController) {
        super.init()
        ImagePickerController.retain = self
        self.presenter = presenter
    }

    open func present() {
        if let p = presenter {
            p.present(imagePicker, animated: true) {
                if #available(iOS 14, *) {
                    DispatchQueue.main.async {
                        PHPhotoLibrary.requestAuthorization { _ in }
                    }
                }
            }
        }
    }

    // MARK: UIImagePickerControllerDelegate, UINavigationControllerDelegate

    open func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        close(picker: picker)
        callback?(AttachmentView(info: info))
    }

    open func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        close(picker: picker)
        let cb = callback
        ImagePickerController.retain = nil
        cb?(nil)
    }

    open func close(picker: UIViewController) {
        picker.dismiss(animated: true)
    }
}

private extension AttachmentView {
    init?(info: [UIImagePickerController.InfoKey: Any]) {
        guard let mediaType = info[.mediaType] as? String
        else { return nil }

        switch mediaType {
        case "public.image":
            if let thumbnail = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
               let jpeg = Components.imageBuilder.init(image: thumbnail).jpegData(compressionQuality: SceytChatUIKit.shared.config.imageAttachmentResizeConfig.compressionQuality),
               let url = Components.storage.storeData(jpeg, filename: UUID().uuidString + ".jpg")
            {
                self.init(mediaUrl: url, thumbnail: thumbnail)
            } else {
                return nil
            }
        case "public.movie":
            if let url = info[.mediaURL] as? URL,
               let fileUrl = Components.storage.copyFile(url),
               let thumbnail = Components.videoProcessor.copyFrame(url: fileUrl)
            {
                let duration = Int(AVURLAsset(url: fileUrl).duration.seconds)
                let size = Components.videoProcessor.resolutionSize(url: fileUrl)
                self.init(
                    mediaUrl: fileUrl,
                    thumbnail: thumbnail,
                    imageSize: size,
                    duration: duration
                )
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}
