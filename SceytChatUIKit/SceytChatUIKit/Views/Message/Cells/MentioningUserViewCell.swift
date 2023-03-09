//
//  MentioningUserViewCell.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat

open class MentioningUserViewCell: TableViewCell {

    open lazy var avatarView = CircleImageView()
        .withoutAutoresizingMask

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var onlineStatusView = UIImageView()
        .withoutAutoresizingMask

    open var imageTask: Cancellable?

    open override func setupAppearance() {
        super.setupAppearance()
        selectionStyle = .gray
        titleLabel.textAlignment = .left
        titleLabel.font = appearance.titleLabelFont
        titleLabel.backgroundColor = .clear
        onlineStatusView.image = Images.online
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(onlineStatusView)
        avatarView.pin(to: contentView, anchors: [.leading(16), .top(3), .bottom(-3)])
        avatarView.resize(anchors: [.width(40), .height(40)])
        titleLabel.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10)
        titleLabel.centerYAnchor.pin(to: avatarView.centerYAnchor)
        titleLabel.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -10)
        separatorInset.left = 66
        onlineStatusView.pin(to: avatarView, anchors: [.trailing(), .bottom()])
    }

    open var data: ChatChannelMember! {
        didSet {
            guard let data = data else { return }
            titleLabel.text = Formatters.userDisplayName.format(data)
            if me == data.id {
                titleLabel.text! += " (\(L10n.User.current))"
            }
            onlineStatusView.isHidden = data.presence.state != .online
            imageTask = Components.avatarBuilder.loadAvatar(into: avatarView.imageView, for: data)
        }
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
    }
}
