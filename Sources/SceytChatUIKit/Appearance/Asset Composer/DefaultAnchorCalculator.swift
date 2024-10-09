//
//  DefaultAnchorCalculator.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 28.08.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

public protocol AnchorCalculating {
    func calculate(anchor: AssetComposer.Anchor, for size: CGSize, inMaxSize maxSize: CGSize) -> CGPoint
}

open class DefaultAnchorCalculator: AnchorCalculating {
    public init() {}
    open func calculate(anchor: AssetComposer.Anchor, for size: CGSize, inMaxSize maxSize: CGSize) -> CGPoint {
        guard size != maxSize else { return .zero }
        
        switch anchor {
        case .top(let offset):
            return CGPoint(x: (maxSize.width - size.width) / 2 + offset.x, y: offset.y)
        case .topLeading(let offset):
            return CGPoint(x: offset.x, y: offset.y)
        case .topTrailing(let offset):
            return CGPoint(x: maxSize.width - size.width + offset.x, y: offset.y)
        case .center(let offset):
            return CGPoint(x: (maxSize.width - size.width) / 2 + offset.x, y: (maxSize.height - size.height) / 2 + offset.y)
        case .bottom(let offset):
            return CGPoint(x: (maxSize.width - size.width) / 2 + offset.x, y: maxSize.height - size.height + offset.y)
        case .bottomLeading(let offset):
            return CGPoint(x: offset.x, y: maxSize.height - size.height + offset.y)
        case .bottomTrailing(let offset):
            return CGPoint(x: maxSize.width - size.width + offset.x, y: maxSize.height - size.height + offset.y)
        case .leading(let offset):
            return CGPoint(x: offset.x, y: (maxSize.height - size.height) / 2 + offset.y)
        case .trailing(let offset):
            return CGPoint(x: maxSize.width - size.width + offset.x, y: (maxSize.height - size.height) / 2 + offset.y)
        }
    }
}
