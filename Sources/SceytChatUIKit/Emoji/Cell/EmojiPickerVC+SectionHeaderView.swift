//
//  EmojiPickerViewController+SectionHeaderView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension EmojiPickerViewController {
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
            backgroundColor = appearance.backgroundColor
            label.textColor = appearance.labelAppearance.foregroundColor
            label.font = appearance.labelAppearance.font
        }
        
        open func bind(_ data: String?) {
            label.text = data
        }
    }
}
