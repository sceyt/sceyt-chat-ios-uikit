//
//  UserReactionCell.swift
//  SceytChatUIKit
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
            userLabel.text = data.displayName
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView.imageView, for: data)
        }
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        userLabel.font = Fonts.semiBold.withSize(16)
        reactionLabel.font = Fonts.bold.withSize(24)
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
