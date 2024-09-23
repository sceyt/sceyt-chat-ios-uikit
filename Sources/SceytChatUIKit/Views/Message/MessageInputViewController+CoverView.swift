//
//  MessageInputViewController+CoverView.swift
//  SceytChatUIKit
//
//  Created by Duc on 20/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInputViewController {
    open class CoverView: View {
        open var icon: UIImage? {
            set {
                iconView.image = newValue?.withRenderingMode(.alwaysTemplate)
            }
            get {
                iconView.image
            }
        }
        open var message: String? {
            set {
                textLabel.text = newValue
            }
            get {
                textLabel.text
            }
        }
        
        open lazy var iconView = UIImageView()
            .contentMode(.center)
        
        open lazy var textLabel = UILabel()
        
        open lazy var hStack = UIStackView(row: [iconView, textLabel], spacing: 8)
            .withoutAutoresizingMask
        
        open lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        override open func setupLayout() {
            super.setupLayout()
            
            addSubview(hStack)
            addSubview(separatorView)
            hStack.pin(to: self, anchors: [
                .centerX,
                .centerY,
                .leading(0, .greaterThanOrEqual),
                .top(0, .greaterThanOrEqual),
                .trailing(0, .lessThanOrEqual),
                .bottom(0, .lessThanOrEqual)
            ])
            separatorView.pin(to: self, anchors: [.top, .trailing, .leading])
            separatorView.heightAnchor.pin(constant: 1)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            iconView.tintColor = appearance.iconColor
            textLabel.font = appearance.labelFont
            textLabel.textColor = appearance.labelColor
            separatorView.backgroundColor = appearance.separatorColor
        }
    }
}
