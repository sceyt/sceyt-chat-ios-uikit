//
//  LabelAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class LabelAppearance {
    public var foregroundColor: UIColor?
    public var font: UIFont
    public var backgroundColor: UIColor = .clear

    public init(foregroundColor: UIColor?, font: UIFont, backgroundColor: UIColor = .clear) {
        self.foregroundColor = foregroundColor
        self.font = font
        self.backgroundColor = backgroundColor
    }
}
