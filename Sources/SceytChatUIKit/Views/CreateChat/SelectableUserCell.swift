//
//  SelectableUserCell.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class SelectableUserCell: BaseChannelUserCell {
    
    open lazy var checkBoxView = Components.checkBoxView.init()
        .withoutAutoresizingMask

    override open func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        checkBoxView.isSelected = selected
    }

    open var userData: ChatUser! {
        didSet {
            titleLabel.text = userData.displayName
            statusLabel.text = SceytChatUIKit.shared.formatters.userPresenceDateFormatter.format(userData)
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView.imageView, for: userData)
            subscribeForPresence()
        }
    }
    
    open func subscribeForPresence() {
        guard let contact = userData
        else { return }
        Components.presenceProvider
            .subscribe(userId: contact.id) { [weak self] userPresence in
                PresenceProvider.unsubscribe(userId: contact.id)
                guard let self, userPresence.userId == self.userData.id
                else { return }
                self.statusLabel.text = SceytChatUIKit.shared.formatters.userPresenceDateFormatter.format(.init(user: userPresence.user))
            }
    }
    
    override open func setup() {
        super.setup()
        
        checkBoxView.isUserInteractionEnabled = false
        selectionStyle = .none
    }
    
    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(checkBoxView)
        
        checkBoxView.pin(to: contentView, anchors: [.leading(6), .centerY()])
        checkBoxView.resize(anchors: [.width(44), .height(44)])
        avatarView.leadingAnchor.pin(to: checkBoxView.trailingAnchor, constant: 2)
    }

    
    override open func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = appearance.backgroundColor
        contentView.backgroundColor = appearance.backgroundColor
        separatorView.backgroundColor = appearance.separatorColor
        
        titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
        titleLabel.font = appearance.titleLabelAppearance.font
        statusLabel.textColor = appearance.subtitleLabelAppearance?.foregroundColor
        statusLabel.font = appearance.subtitleLabelAppearance?.font
    }
}
