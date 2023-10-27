//
//  CreateChatActionsView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class CreateChatActionsView: View {
    open lazy var groupView = HighlightableControl()
        .withoutAutoresizingMask
    
    open lazy var channelView = HighlightableControl()
        .withoutAutoresizingMask
    
    open lazy var groupIconView: UIImageView = {
        $0.image = .channelCreatePrivate
        $0.contentMode = .center
        return $0.withoutAutoresizingMask
    }(UIImageView())
    
    open lazy var groupTitleLabel: UILabel = {
        $0.text = L10n.Channel.New.createPrivate
        $0.textAlignment = .left
        return $0.withoutAutoresizingMask
    }(UILabel())

    open lazy var channelIconView: UIImageView = {
        $0.image = .channelCreatePublic
        $0.contentMode = .center
        return $0.withoutAutoresizingMask
    }(UIImageView())
    
    open lazy var channelTitleLabel: UILabel = {
        $0.text = L10n.Channel.New.createPublic
        $0.textAlignment = .left
        return $0.withoutAutoresizingMask
    }(UILabel())
    
    override open func setupLayout() {
        super.setupLayout()
        
        addSubview(groupView)
        addSubview(channelView)
        
        groupView.resize(anchors: [.height(48)])
        channelView.resize(anchors: [.height(48)])
        
        groupView.pin(to: self, anchors: [.leading(), .top(), .trailing()])
        channelView.pin(to: self, anchors: [.leading(), .bottom(), .trailing()])
        channelView.topAnchor.pin(to: groupView.bottomAnchor)

        groupView.addSubview(groupIconView)
        groupView.addSubview(groupTitleLabel)
        
        channelView.addSubview(channelIconView)
        channelView.addSubview(channelTitleLabel)
        
        groupIconView.pin(to: groupView, anchor: .leading(16))
        groupIconView.resize(anchors: [.width(28), .height(28)])
        groupIconView.centerYAnchor.pin(to: groupView.centerYAnchor)
        
        groupTitleLabel.leadingAnchor.pin(to: groupIconView.trailingAnchor, constant: 16)
        groupTitleLabel.trailingAnchor.pin(to: groupView.trailingAnchor, constant: -16)
        groupTitleLabel.centerYAnchor.pin(to: groupView.centerYAnchor)
        
        channelIconView.pin(to: channelView, anchor: .leading(16))
        channelIconView.resize(anchors: [.width(28), .height(28)])
        channelIconView.centerYAnchor.pin(to: channelView.centerYAnchor)
        
        channelTitleLabel.leadingAnchor.pin(to: channelIconView.trailingAnchor, constant: 16)
        channelTitleLabel.trailingAnchor.pin(to: channelView.trailingAnchor, constant: -16)
        channelTitleLabel.centerYAnchor.pin(to: channelView.centerYAnchor)
    }
    
    override open func setupAppearance() {
        super.setupAppearance()
        
        groupTitleLabel.font = appearance.font
        groupTitleLabel.textColor = appearance.color
        
        channelTitleLabel.font = appearance.font
        channelTitleLabel.textColor = appearance.color
    }
}
