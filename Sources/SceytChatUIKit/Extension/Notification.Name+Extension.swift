//
//  Notification.Name+Extension.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/06/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let didUpdateDeliveryStatus = Notification.Name("didUpdateDeliveryStatus")
    static let selectMessage = Notification.Name("selectMessage")
    static let didUpdateLocalCreateChannelOnEventChannelCreate = Notification.Name("didUpdateLocalCreateChannelOnEventChannelCreate")
    static let didUpdateMessagePoll = Notification.Name("didUpdatePoll")
    static let didClosePoll = Notification.Name("didClosePoll")
    static let didOpenViewOnceMessage = Notification.Name("didOpenViewOnceMessage")
    static let didFinishChannelsSync = Notification.Name("didFinishChannelsSync")
    /// One channel's pinned-message sweep finished and reconciled. `userInfo["channelId"]`
    /// carries the `ChannelId`.
    static let didFinishChannelPinsSync = Notification.Name("didFinishChannelPinsSync")
    static let didSendUserMessage = Notification.Name("didSendUserMessage")
}
