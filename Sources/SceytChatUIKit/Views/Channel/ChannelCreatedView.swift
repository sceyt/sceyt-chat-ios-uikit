//
//  ChannelCreatedView.swift
//  SceytChatUIKit
//
//  Created by Duc on 20/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ChannelCreatedView: View {
    open lazy var iconView = UIImageView()
    open lazy var titleLabel = ContentInsetLabel()
    open lazy var messageLabel = ContentInsetLabel()
    open lazy var vStack = UIStackView(column: [iconView, titleLabel, messageLabel], spacing: 16, alignment: .center)
        .withoutAutoresizingMask
    
    open override func setup() {
        super.setup()
        
        iconView.image = appearance.channelCreatedImage
        titleLabel.text = L10n.Channel.Created.title
        messageLabel.text = L10n.Channel.Created.message
        titleLabel.numberOfLines = 0
        messageLabel.numberOfLines = 0
        titleLabel.edgeInsets = .init(top: 4, left: 12, bottom: 4, right: 12)
        messageLabel.edgeInsets = .init(top: 4, left: 12, bottom: 4, right: 12)
        titleLabel.textAlignment = .center
        messageLabel.textAlignment = .center
        titleLabel.layer.cornerRadius = 12
        messageLabel.layer.cornerRadius = 12
        titleLabel.layer.masksToBounds = true
        messageLabel.layer.masksToBounds = true
    }
    
    open override func setupLayout() {
        super.setupLayout()
        
        addSubview(vStack)
        vStack.pin(to: self, anchors: [.leading(16, .greaterThanOrEqual), .centerX, .bottom(-20)])
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        titleLabel.backgroundColor = appearance.labelBackgroundColor
        messageLabel.backgroundColor = appearance.labelBackgroundColor
        titleLabel.font = appearance.titleLabelFont
        messageLabel.font = appearance.messageLabelFont
        titleLabel.textColor = appearance.titleLabelColor
        messageLabel.textColor = appearance.messageLabelColor
    }
}
