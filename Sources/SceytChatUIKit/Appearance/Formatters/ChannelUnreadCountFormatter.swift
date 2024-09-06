//
//  ChannelUnreadCountFormatter.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

open class ChannelUnreadCountFormatter: UIntFormatting {

    public init() {}
    
    open func format( _ count: UInt64) -> String {
        switch count {
        case 1 ..< 100:
            return "\(count)"
        case 100...:
            return "99+"
        default:
            return ""
        }
    }
}
