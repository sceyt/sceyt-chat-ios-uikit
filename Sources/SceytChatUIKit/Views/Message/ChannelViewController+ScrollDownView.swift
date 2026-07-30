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
            // Surface as a single button for VoiceOver and UI tests (a bare
            // UIControl is not an accessibility element by default).
            isAccessibilityElement = true
            accessibilityTraits = .button
        }

        /// Surfacing the button as a single accessibility element collapses the
        /// child badge, so the unread count is reported as the button's value —
        /// readable by VoiceOver and by UI tests, without splitting this into
        /// two unlabeled elements.
        override open var accessibilityValue: String? {
            get {
                guard let count = unreadCount.value, !count.isEmpty
                else { return nil }
                return count
            }
            set { super.accessibilityValue = newValue }
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
            
            backgroundColor = appearance.backgroundColor
            bubbleView.image = Components.imageBuilder.addShadow(to: appearance.icon,
                                                                 blur: 12)
            unreadCount.font = appearance.unreadCountLabelAppearance.font
            unreadCount.textColor = appearance.unreadCountLabelAppearance.foregroundColor
            unreadCount.backgroundColor = appearance.unreadCountLabelAppearance.backgroundColor
        }
    }
    
}
