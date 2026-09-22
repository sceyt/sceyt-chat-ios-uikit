//
//  ChannelViewController+UnreadMentionCountView.swift
//  SceytChatUIKit
//
//  Created by Vahagn Manasyan on 29.07.25.
//

import UIKit

extension ChannelViewController {
    open class UnreadMentionCountView: Control {
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

        override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            print("touchesBegan in UnreadMentionCountView")
        }
    }
}
