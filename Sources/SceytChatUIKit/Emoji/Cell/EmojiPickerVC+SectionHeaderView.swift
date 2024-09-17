//
//  EmojiPickerVC+SectionHeaderView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension EmojiPickerVC {
    open class SectionHeaderView: CollectionReusableView, Bindable {
        
        private var isConfigured = false
        
        open lazy var label = UILabel()
            .withoutAutoresizingMask
        
        open override func setup() {
            super.setup()
        }
        
        open override func setupLayout() {
            super.setupLayout()
            addSubview(label)
            label.pin(to: self, anchors: [.top(), .leading(12), .trailing(), .bottom()])
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            label.textColor = appearance.textColor
            label.font = appearance.textFont
        }
        
        open func bind(_ data: String?) {
            label.text = data
        }
    }
}
