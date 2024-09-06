//
//  Formatting.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.09.24.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

public protocol Formatting {
    associatedtype U
    func format(_: U) -> String
}

public protocol UserFormatting: Formatting {
    func format(_ user: ChatUser) -> String
    func short(_ user: ChatUser) -> String
}

public protocol UserPresenceFormatting: Formatting {
    func format(_ presence: ChatUser.Presence) -> String
}

public protocol DateFormatting: Formatting {
    func format(_ date: Date) -> String
}

public protocol ChannelFormatting: Formatting {
    func format( _ channel: ChatChannel) -> String
}

public protocol UIntFormatting: Formatting {
    func format( _ count: UInt64) -> String
}

public protocol StringFormatting {
    func format(_ initials: String) -> String
}

public protocol TimeIntervalFormatting {
    func format(_ timeInterval: TimeInterval) -> String
}
