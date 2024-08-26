//
//  UserReactionCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class UserReactionCell: CollectionViewCell {

    open lazy var avatarView = CircleImageView()
        .withoutAutoresizingMask
    open lazy var userLabel = UILabel()
        .withoutAutoresizingMask
    open lazy var reactionLabel = UILabel()
        .withoutAutoresizingMask
    open var imageTask: Cancellable?

    open var data: ChatUser! {
        didSet {
            guard let data = data else { return }
            if data.id == me {
                userLabel.text = L10n.User.current
            } else {
                userLabel.text = data.displayName
            }
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView.imageView, for: data)
        }
    }
    
    open override func setup() {
        super.setup()
        selectedBackgroundView = UIView()
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        selectedBackgroundView?.backgroundColor = UIColor.surface2
        userLabel.font = appearance.userLabelFont
        reactionLabel.font = appearance.reactionLabelFont
        userLabel.textColor = appearance.userLabelColor
        reactionLabel.textColor = appearance.reactionLabelColor
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
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
    }

}
