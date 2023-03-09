//
//  SceytChat+Extention.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat

var chatClient: ChatClient {
    ChatClient.shared
}

var me: UserId {
    chatClient.user.id
}

extension ConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connected:
            return "connected"
        case .connecting:
            return "connecting"
        case .disconnected:
            return "disconnected"
        case .reconnecting:
            return "reconnecting"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown"
        }
    }
}

extension MessageDeliveryStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .pending:
            return "pending"
        case .sent:
            return "sent"
        case .received:
            return "received"
        case .displayed:
            return "displayed"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown"
        }
    }
}

extension PresenceState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .offline:
            return "offline"
        case .online:
            return "online"
        case .invisible:
            return "invisible"
        case .away:
            return "away"
        case .DND:
            return "DND"
        @unknown default:
            return "unknown"
        }
    }
}

internal extension Error {
    
    var code: Int {
        (self as NSError).code
    }
    
    var sceytCode: ErrorCode {
        ErrorCode(rawValue: code) ?? .unknown
    }
}
