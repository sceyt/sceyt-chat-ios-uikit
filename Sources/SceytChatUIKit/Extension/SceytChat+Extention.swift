//
//  SceytChat+Extention.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat


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
