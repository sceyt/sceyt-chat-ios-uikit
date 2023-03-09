//
//  URL+Extension.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import Foundation
import MobileCoreServices
import UniformTypeIdentifiers

public extension URL {

    func mimeType() -> String {
        var mimeType: String?
        let pathExtension = self.pathExtension
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as NSString, nil)?.takeRetainedValue() {
            if #available(iOS 14.0, *) {
                mimeType = UTType(uti as String)?.preferredMIMEType
            } else {
                mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeUnretainedValue() as String?
            }
        }
        return mimeType ?? "application/octet-stream"
    }
    private var uti: CFString? {
        UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType() as CFString, nil)?.takeRetainedValue()
    }
    var isImage: Bool {
        guard let uti = uti else { return false }
        return UTTypeConformsTo(uti, kUTTypeImage)
    }
    var isAudio: Bool {
        guard let uti = uti else { return false }
        return UTTypeConformsTo(uti, kUTTypeAudio)
    }
    var isVideo: Bool {
        guard let uti = uti else { return false }
        return UTTypeConformsTo(uti, kUTTypeMovie)
    }
    
    var sanitise: URL {
        if var components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            if components.scheme == nil {
                components.scheme = "http"
            }
            
            return components.url ?? self
        }
        
        return self
    }
}

