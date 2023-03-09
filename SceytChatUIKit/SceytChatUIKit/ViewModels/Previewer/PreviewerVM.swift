//
//  PreviewerVM.swift
//  SceytChatUIKit
//

import Foundation
import Photos

open class PreviewerVM {
    
    open class func save(attachment: ChatMessage.Attachment, completion: @escaping (Event) -> Void) {
        if attachment.type == "video" {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: attachment.originUrl)
            }) { _, error in
                completion(.videoSaved(error))
            }
        } else {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: attachment.originUrl)
            }) { _, error in
                completion(.photoSaved(error))
            }
        }
    }
}

extension PreviewerVM {
    
    public enum Event {
        case photoSaved(Error?)
        case videoSaved(Error?)
    }
}
