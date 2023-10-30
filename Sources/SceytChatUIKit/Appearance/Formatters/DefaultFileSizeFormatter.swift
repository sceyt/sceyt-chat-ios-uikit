//
//  DefaultFileSizeFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class DefaultFileSizeFormatter: FileSizeFormatter {

    public init() {}
    
    open func format(_ size: UInt) -> String {
        let chunk = UInt(1000)
        switch size {
        case 0 ..< chunk:
            return "\(size)B"
        case chunk + 1 ..< chunk * chunk:
            return String(format: "%.2fKB", Double(size) / Double(chunk))
        case chunk * chunk + 1 ..< chunk * chunk * chunk:
            return String(format: "%.2fMB", Double(size) / Double(chunk * chunk))
        default:
            return String(format: "%.2fGB", Double(size) / Double(chunk * chunk * chunk))
        }
    }
}
