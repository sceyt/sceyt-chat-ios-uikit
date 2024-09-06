//
//  MentioningUserViewCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
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
        
        backgroundColor = .clear
        selectionStyle = .gray
        titleLabel.textAlignment = .left
        titleLabel.font = appearance.titleLabelFont
        onlineStatusView.image = Images.online
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(onlineStatusView)
        avatarView.pin(to: contentView, anchors: [
            .leading(Layouts.avatarLeftPaddding),
            .top(Layouts.avatarVerticalPadding, .greaterThanOrEqual),
            .centerY
        ])
        avatarView.resize(anchors: [.width(Layouts.avatarSize), .height(Layouts.avatarSize)])
        titleLabel.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10)
        titleLabel.centerYAnchor.pin(to: avatarView.centerYAnchor)
        titleLabel.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -10)
        onlineStatusView.pin(to: avatarView, anchors: [.trailing(), .bottom()])
        
        layer.cornerRadius = Components.mentioningUserListVC.Layouts.cornerRadius
        layer.masksToBounds = true
    }

    open var data: ChatChannelMember! {
        didSet {
            guard let data = data else { return }
            titleLabel.text = SceytChatUIKit.shared.formatters.userNameFormatter.format(data)
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
    
    open override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        contentView.backgroundColor = highlighted ? UIColor.surface2 : .clear
    }
    
    open override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        contentView.backgroundColor = selected ? UIColor.surface2 : .clear
    }
}

public extension MentioningUserViewCell {
    enum Layouts {
        public static var avatarSize: CGFloat = 40
        public static var avatarLeftPaddding: CGFloat = 16
        public static var avatarVerticalPadding: CGFloat = 6
        public static var cellHeight: CGFloat { avatarSize + avatarVerticalPadding * 2 }
        public static var verticalPadding: CGFloat = 4
    }
}
