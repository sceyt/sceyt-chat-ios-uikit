//
//  UIPasteboard+Extension.swift
//  SceytChatUIKit
//
//  Created by Duc on 25/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import MobileCoreServices

public extension UIPasteboard {
    func set(_ attributedString: NSAttributedString) throws {
        let rtf = try attributedString.data(from: NSMakeRange(0, attributedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf])
        items = [[kUTTypeRTF as String: NSString(data: rtf, encoding: String.Encoding.utf8.rawValue)!, kUTTypeUTF8PlainText as String: attributedString.string]]
    }
}
