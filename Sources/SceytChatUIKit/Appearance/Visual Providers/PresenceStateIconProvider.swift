//
//  PresenceStateIconProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

public struct PresenceStateIconProvider: PresenceStateIconProviding {
    
    public func provideVisual(for state: ChatUser.Presence.State) -> UIImage? {
        switch state {
        case .offline:
            nil
        case .online:
                .online
        case .invisible:
            nil
        case .away:
            nil
        case .dnd:
            nil
        }
    }
}

public struct DefaultMarkerTitleProvider: DefaultMarkerTitleProviding {
    
    public func provideVisual(for marker: DefaultMarker) -> String {
        switch marker {
        case .displayed:
            L10n.Message.Info.readBy
        case .received:
            L10n.Message.Info.deliveredTo
        case .played:
            L10n.Message.Info.playedBy
        case .custom(let custom):
            custom
        }
    }
}
