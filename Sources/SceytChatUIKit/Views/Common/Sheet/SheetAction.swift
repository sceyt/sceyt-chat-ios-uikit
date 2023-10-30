//
//  SheetAction.swift
//  SceytChatUIKit
//
//  Created by Duc on 03/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public struct SheetAction {
    public init(title: String, icon: UIImage? = nil, style: Style = .default, handler: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.style = style
        self.handler = handler
    }

    public var title: String
    public var icon: UIImage?
    public var style: Style
    public var handler: (() -> Void)?

    public enum Style {
        case `default`, destructive, cancel
    }
}
