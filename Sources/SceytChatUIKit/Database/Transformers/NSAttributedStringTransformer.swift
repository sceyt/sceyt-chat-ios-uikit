//
//  NSAttributedStringTransformer.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation


@objc(NSAttributedStringTransformer)
open class NSAttributedStringTransformer: NSSecureUnarchiveFromDataTransformer {
    
    override open class var allowedTopLevelClasses: [AnyClass] {
        super.allowedTopLevelClasses + [NSAttributedString.self]
    }
}
