//
//  ChannelUnreadMessageCount.swift
//  SceytChatUIKit
//

import Foundation

public protocol ChannelUnreadMessageCount {

    func format( _ count: UInt64) -> String

}

open class DefaultChannelUnreadMessageCount: ChannelUnreadMessageCount {

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

