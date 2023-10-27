//
//  PickedData.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public struct PickedData {
    //Image
    public var originalImage: UIImage?
    public var editedImage: UIImage?
    public var mediaURL: URL?
    public var imageURL: URL?
    public var mediaType: String?
    public var mediaMetadata: [AnyHashable: Any]?
    
    //Documents
    public var documents: [URL]?
    
    var fileURL: URL? {
        imageURL ?? mediaURL
    }
    
}
