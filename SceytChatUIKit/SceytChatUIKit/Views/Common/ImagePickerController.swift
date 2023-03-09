//
//  ImagePickerController.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import AVFoundation
import CoreServices
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
            p.present(imagePicker, animated: true)
        }
    }

    // MARK: UIImagePickerControllerDelegate, UINavigationControllerDelegate

    open func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any])
    {
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
               let jpeg = Components.imageBuilder.init(image: thumbnail).jpegData(),
               let url = Storage.storeData(jpeg, filename: UUID().uuidString + ".jpg")
            {
                self.init(mediaUrl: url, thumbnail: thumbnail)
            } else {
                return nil
            }
        case "public.movie":
            if let url = info[.mediaURL] as? URL,
               let fileUrl = Storage.copyFile(url),
               let thumbnail = Components.videoProcessor.copyFrame(url: fileUrl)
            {
                let duration = Int(AVURLAsset(url: fileUrl).duration.seconds)
                self.init(
                    mediaUrl: fileUrl,
                    thumbnail: thumbnail,
                    duration: duration)
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}
