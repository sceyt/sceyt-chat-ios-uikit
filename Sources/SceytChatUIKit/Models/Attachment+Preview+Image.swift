//
//  Attachment+Preview+Image.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public extension ChatMessage.Attachment {
    
    var originalImage: UIImage? {
        if let filePath,
            let image = UIImage(contentsOfFile: filePath) {
            return image
        }
        return thumbnailImage
    }
    
    var thumbnailImage: UIImage? {
        guard let path = fileProvider.thumbnailFile(for: self, preferred: MessageLayoutModel.defaults.imageAttachmentSize)
        else {
            if let image = imageDecodedMetadata?.thumbnailImage {
                return image
            } else if let thumbnail = imageDecodedMetadata?.thumbnail,
                      let image = Components.imageBuilder.image(from: thumbnail)
            {
                return image
            }
            return nil
        }
        return UIImage(contentsOfFile: path)
    }
}
