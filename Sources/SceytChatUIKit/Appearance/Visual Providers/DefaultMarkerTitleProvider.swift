//
//  DefaultMarkerTitleProvider.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 08.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public struct DefaultMarkerTitleProvider: DefaultMarkerTitleProviding {
    
    public init() {}
    
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
