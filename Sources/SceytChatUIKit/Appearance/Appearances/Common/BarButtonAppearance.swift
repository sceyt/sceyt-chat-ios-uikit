//
//  BarButtonAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct BarButtonAppearance {
    public var text: String? = nil
    public var icon: UIImage? = nil
    public var color: UIColor = .primaryText
    public var inactiveColor: UIColor? = nil
    
    // Initializer with default values
    public init(
        text: String? = nil,
        icon: UIImage? = nil,
        color: UIColor = .primaryText,
        inactiveColor: UIColor? = nil
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.inactiveColor = inactiveColor
    }
}
