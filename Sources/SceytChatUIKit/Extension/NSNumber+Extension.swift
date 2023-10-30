//
//  NSNumber+Extension.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension NSNumber: Comparable {

    public static func < (lhs: NSNumber, rhs: NSNumber) -> Bool {
        lhs.compare(rhs) == .orderedDescending
    }
}
