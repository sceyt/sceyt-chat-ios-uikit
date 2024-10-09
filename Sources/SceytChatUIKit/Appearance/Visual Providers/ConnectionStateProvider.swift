//
//  ConnectionStateProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import SceytChat

public struct ConnectionStateTextProvider: ConnectionStateProviding {
    public func provideVisual(for state: ConnectionState) -> String {
        switch state {
        case .connected:    ""
        case .disconnected: L10n.Connection.State.disconnected
        case .connecting:   L10n.Connection.State.connecting
        case .reconnecting: L10n.Connection.State.reconnecting
        case .failed:       L10n.Connection.State.failed
        }
    }
}
