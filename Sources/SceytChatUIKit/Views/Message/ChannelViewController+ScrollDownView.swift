//
//  ChannelViewController+ScrollDownView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController {
    open class ScrollDownView: Control {
        open lazy var bubbleView = UIImageView()
            .withoutAutoresizingMask
        
        open lazy var unreadCount = Components.badgeView
            .init()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)
        
        override open func setup() {
            super.setup()
            
            unreadCount.value = nil
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            addSubview(bubbleView)
            addSubview(unreadCount)
            bubbleView.pin(to: self, anchors: [.leading(-12), .bottom(12), .trailing(12), .top(4.0 - 12)])
            unreadCount.trailingAnchor.pin(to: trailingAnchor)
            unreadCount.topAnchor.pin(to: topAnchor)
            unreadCount.resize(anchors: [.height(18), .width(18, .greaterThanOrEqual)])
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            bubbleView.image = ImageBuilder.addShadow(to: appearance.icon,
                                                      blur: 12)
            unreadCount.font = appearance.unreadCountLabelAppearance.font
            unreadCount.textColor = appearance.unreadCountLabelAppearance.foregroundColor
            unreadCount.backgroundColor = appearance.unreadCountLabelAppearance.backgroundColor
        }
    }
    
}
