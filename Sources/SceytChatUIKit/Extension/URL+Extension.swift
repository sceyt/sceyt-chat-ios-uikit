//
//  URL+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import Foundation
import MobileCoreServices
import UIKit
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

    var fileIcon: UIImage? {
        let documentInteractionController = UIDocumentInteractionController()
        documentInteractionController.name = lastPathComponent
        documentInteractionController.url = self
        documentInteractionController.uti = uti as String?
        return documentInteractionController.icons.last
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
    
    init?(string: String?) {
        if let string {
            self.init(string: string, relativeTo: nil)
        } else {
            return nil
        }
    }
    
    func isEqual(url: URL) -> Bool {
        
        func normalizeURL(_ urlString: String) -> URL {
            // Check if the URL has a scheme, if not, prepend 'http://'
            var normalizedString = urlString
            if !normalizedString.contains("://") {
                normalizedString = "http://" + normalizedString
            }

            // Return URL, assuming the string is a valid URL
            return URL(string: normalizedString)!
        }
        
        let normalizedUrl1 = normalizeURL(self.absoluteString)
        let normalizedUrl2 = normalizeURL(url.absoluteString)

        return normalizedUrl1.host == normalizedUrl2.host && normalizedUrl1.path == normalizedUrl2.path
    }
    
    var normalizedURL: URL {
        if self.scheme != nil {
            return self
        }
        if absoluteString.contains("://") {
            return self
        }
        if let url = URL(string: "http://" + absoluteString) {
            return url
        }
        if let url = URL(string: "https://" + absoluteString) {
            return url
        }
        return self
    }
}
