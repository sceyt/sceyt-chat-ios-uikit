//
//  MessageCell+InfoViewBackgroundView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell {
    open class InfoViewBackgroundView: View {
        override open func setup() {
            clipsToBounds = true
        }
        
        override open func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = bounds.height / 2
        }
    }
}
