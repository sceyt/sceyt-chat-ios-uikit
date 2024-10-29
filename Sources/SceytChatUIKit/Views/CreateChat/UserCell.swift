//
//  UserCell.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 26.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class UserCell: BaseChannelUserCell {
    
    open var userData: ChatUser! {
        didSet {
            titleLabel.text = appearance.titleFormatter.format(userData)
            statusLabel.text = appearance.subtitleFormatter.format(userData)
            imageTask = appearance.avatarRenderer.render(
                userData,
                with: appearance.avatarAppearance,
                into: avatarView
            )
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
                self.statusLabel.text = appearance.subtitleFormatter.format(.init(user: userPresence.user))
            }
    }
    
    override open func setupLayout() {
        super.setupLayout()
        
        avatarView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: Layouts.horizontalPadding)
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
