//
//  StartChatViewController+ActionsView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension StartChatViewController {
    open class ActionsView: View {
        
        open var appearance: StartChatViewController.Appearance = StartChatViewController.appearance
        
        open lazy var groupView = HighlightableControl()
            .withoutAutoresizingMask
        
        open lazy var channelView = HighlightableControl()
            .withoutAutoresizingMask
        
        open lazy var groupIconView: UIImageView = {
            $0.image = appearance.createGroupIcon
            $0.contentMode = .center
            return $0.withoutAutoresizingMask
        }(UIImageView())
        
        open lazy var groupTitleLabel: UILabel = {
            $0.text = appearance.createGroupText
            $0.textAlignment = .left
            return $0.withoutAutoresizingMask
        }(UILabel())
        
        open lazy var channelIconView: UIImageView = {
            $0.image = appearance.createChannelIcon
            $0.contentMode = .center
            return $0.withoutAutoresizingMask
        }(UIImageView())
        
        open lazy var channelTitleLabel: UILabel = {
            $0.text = appearance.createChannelText
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
            
            groupIconView.image = appearance.createGroupIcon
            groupTitleLabel.text = appearance.createGroupText
            groupTitleLabel.font = appearance.createGroupLabelAppearance.font
            groupTitleLabel.textColor = appearance.createGroupLabelAppearance.foregroundColor
            
            channelIconView.image = appearance.createChannelIcon
            channelTitleLabel.text = appearance.createChannelText
            channelTitleLabel.font = appearance.createChannelLabelAppearance.font
            channelTitleLabel.textColor = appearance.createChannelLabelAppearance.foregroundColor
        }
    }
}
