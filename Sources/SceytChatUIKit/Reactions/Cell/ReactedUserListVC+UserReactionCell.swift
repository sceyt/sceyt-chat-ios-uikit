//
//  ReactedUserListViewController+UserReactionCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ReactedUserListViewController {
    open class UserReactionCell: CollectionViewCell {
        
        open lazy var avatarView = ImageView()
            .withoutAutoresizingMask
        open lazy var userLabel = UILabel()
            .withoutAutoresizingMask
        open lazy var reactionLabel = UILabel()
            .withoutAutoresizingMask
        /// Transparent hit area covering the avatar and the user name. Tapping it opens
        /// the reacted user's profile; it is switched off for the current user's own row
        /// so the tap falls through to the cell and keeps removing the reaction.
        open lazy var profileButton = UIButton()
            .withoutAutoresizingMask
        open var imageTask: Cancellable?
        
        open var onTapProfile: ((ChatUser) -> Void)?
        
        open var data: ChatMessage.Reaction! {
            didSet {
                guard let user = data.user else { return }
                userLabel.text = appearance.titleFormatter.format(user)
                reactionLabel.text = appearance.subtitleFormatter.format(data)
                
                let isCurrentUser = user.id == SceytChatUIKit.shared.currentUserId
                profileButton.isEnabled = !isCurrentUser
                profileButton.isUserInteractionEnabled = !isCurrentUser
                
                imageTask = appearance.avatarRenderer.render(
                    user,
                    with: appearance.avatarAppearance,
                    into: avatarView
                )
            }
        }
        
        open override func setup() {
            super.setup()
            selectedBackgroundView = UIView()
            profileButton.addTarget(self, action: #selector(profileButtonAction), for: .touchUpInside)
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            backgroundColor = .clear
            selectedBackgroundView?.backgroundColor = appearance.backgroundColor
            userLabel.font = appearance.titleLabelAppearance.font
            userLabel.textColor = appearance.titleLabelAppearance.foregroundColor
            reactionLabel.font = appearance.subtitleLabelAppearance?.font
            reactionLabel.textColor = appearance.subtitleLabelAppearance?.foregroundColor
        }
        
        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(avatarView)
            contentView.addSubview(userLabel)
            contentView.addSubview(reactionLabel)
            avatarView.resize(anchors: [.width(40), .height(40)])
            avatarView.pin(to: contentView, anchors: [.leading(16), .top(8), .bottom(-8)])
            userLabel.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 12)
            userLabel.centerYAnchor.pin(to: avatarView.centerYAnchor)
            reactionLabel.leadingAnchor.pin(greaterThanOrEqualTo: userLabel.trailingAnchor, constant: 8)
            reactionLabel.centerYAnchor.pin(to: avatarView.centerYAnchor)
            reactionLabel.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -18)
            
            contentView.addSubview(profileButton)
            profileButton.leadingAnchor.pin(to: contentView.leadingAnchor)
            profileButton.trailingAnchor.pin(to: userLabel.trailingAnchor)
            profileButton.topAnchor.pin(to: contentView.topAnchor)
            profileButton.bottomAnchor.pin(to: contentView.bottomAnchor)
        }
        
        open override func prepareForReuse() {
            super.prepareForReuse()
            imageTask?.cancel()
        }
        
        @objc
        open func profileButtonAction() {
            guard let user = data?.user else { return }
            onTapProfile?(user)
        }
    }
}
