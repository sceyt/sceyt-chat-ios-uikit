//
//  NSAttributedStringTransformer.swift
//  SceytChatUIKit
//

import Foundation


@objc(NSAttributedStringTransformer)
open class NSAttributedStringTransformer: NSSecureUnarchiveFromDataTransformer {
    
    override open class var allowedTopLevelClasses: [AnyClass] {
        super.allowedTopLevelClasses + [NSAttributedString.self]
    }
}
