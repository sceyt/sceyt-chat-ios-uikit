//
//  CircleButton.swift
//  SceytChatUIKit
//

import UIKit

open class CircleButton: ImageButton {
    
    open override func setup() {
        super.setup()
        clipsToBounds = true
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 0.5 * min(bounds.width, bounds.height)
    }

}
