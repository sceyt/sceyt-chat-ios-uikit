//
//  ChannelUnreadView.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelUnreadCountView: Control {
    
    open lazy var bubbleView = UIImageView(image: .channelUnreadBubble)
        .withoutAutoresizingMask
    
    open lazy var unreadCount = BadgeView()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.required)
    
    open override func setup() {
        super.setup()
        unreadCount.font = appearance.unreadCountFont
        unreadCount.textColor = appearance.unreadCountTextColor
        unreadCount.backgroundColor = appearance.unreadCountBackgroundColor
    }
    open override func setupLayout() {
        addSubview(bubbleView)
        addSubview(unreadCount)
        bubbleView.pin(to: self, anchors: [.leading(), .bottom(), .trailing(), .top(4)])
        unreadCount.trailingAnchor.pin(to: trailingAnchor)
        unreadCount.topAnchor.pin(to: topAnchor)
        unreadCount.resize(anchors: [.height(18), .width(18, .greaterThanOrEqual)])
    }
}
