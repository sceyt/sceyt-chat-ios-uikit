//
//  MessageInfoViewController+HeaderView.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInfoViewController {
    open class HeaderView: TableViewHeaderFooterView {
        open lazy var appearance = Components.messageInfoViewController.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var label = ContentInsetLabel().withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            
            label.edgeInsets = .init(top: 8, left: 0, bottom: 8, right: 0)
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(label)
            label.pin(to: contentView)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            label.font = appearance.headerLabelAppearance.font
            label.textColor = appearance.headerLabelAppearance.foregroundColor
        }
    }
}
