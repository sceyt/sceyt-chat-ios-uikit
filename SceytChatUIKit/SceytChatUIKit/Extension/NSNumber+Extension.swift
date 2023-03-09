//
//  NSNumber+Extension.swift
//  SceytChatUIKit
//

import Foundation

extension NSNumber: Comparable {

    public static func < (lhs: NSNumber, rhs: NSNumber) -> Bool {
        lhs.compare(rhs) == .orderedDescending
    }
}
