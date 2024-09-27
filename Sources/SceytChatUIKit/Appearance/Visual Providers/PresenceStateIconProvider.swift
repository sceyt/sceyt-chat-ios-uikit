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
