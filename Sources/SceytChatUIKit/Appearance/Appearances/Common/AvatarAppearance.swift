//
//  AvatarAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 29.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public struct AvatarAppearance {
    
    public static var standard = AvatarAppearance(
        backgroundColor: .red,
        shape: .roundedRectangle(cornerRadius: 10)
    )
    
    public var backgroundColor: UIColor
    public var shape: Shape
}


// MARK: - Shape

public enum Shape {
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
}
