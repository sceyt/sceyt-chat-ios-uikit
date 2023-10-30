//
//  CircleButton.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class CircleButton: ImageButton {
    
    open override func setup() {
        super.setup()
        clipsToBounds = true
        contentMode = .scaleAspectFill
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 0.5 * min(bounds.width, bounds.height)
    }

}
