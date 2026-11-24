//
//  Data+ImageFileExtension.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

public extension Data {
    /// The file extension of the image these bytes hold ("jpg", "gif", "png", …), read from
    /// the header; nil when they are not an image ImageIO knows.
    var imageFileExtension: String? {
        guard let source = CGImageSourceCreateWithData(self as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String?,
              let utType = UTType(type)
        else { return nil }
        if utType.conforms(to: .jpeg) { return "jpg" }
        return utType.preferredFilenameExtension
    }
}
