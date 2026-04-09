//
//  GlobalSearchMessageCell.swift
//  SceytChatUIKit
//
//  Created by SceytChatUIKit.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

open class GlobalSearchMessageCell: TableViewCell {

    open lazy var avatarView = ImageView()
        .contentMode(.scaleAspectFill)
        .withoutAutoresizingMask

    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var statusLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var timeLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var separatorView = UIView()
        .withoutAutoresizingMask

    open lazy var textVStack = UIStackView(column: [titleLabel, statusLabel], spacing: Layouts.textSpacing)
        .withoutAutoresizingMask

    open var imageTask: Cancellable?

    open var messageData: (channel: ChatChannel, message: ChatMessage)? {
        didSet {
            guard let (channel, message) = messageData else { return }
            imageTask = appearance.avatarRenderer.render(
                channel,
                with: appearance.avatarAppearance,
                into: avatarView
            )
            titleLabel.text = appearance.titleFormatter.format(channel)
            statusLabel.attributedText = attributedStatus(channel: channel, message: message)
            timeLabel.text = appearance.channelDateFormatter.format(message.updatedAt ?? message.createdAt)
        }
    }

    private func senderPrefix(channel: ChatChannel, message: ChatMessage) -> String {
        guard let user = message.user else { return "" }
        if message.state == .deleted || channel.isSelfChannel {
            return ""
        } else if (user.id == SceytChatUIKit.shared.currentUserId) || (user.id.isEmpty && !message.incoming) {
            return "\(L10n.User.current): "
        } else if !channel.isDirect {
            return "\(SceytChatUIKit.shared.formatters.userShortNameFormatter.format(user)): "
        }
        return ""
    }

    private func attributedStatus(channel: ChatChannel, message: ChatMessage) -> NSAttributedString {
        let prefix = senderPrefix(channel: channel, message: message)
        let result = NSMutableAttributedString()
        if !prefix.isEmpty {
            result.append(NSAttributedString(
                string: prefix,
                attributes: [
                    .font: appearance.senderNameLabelAppearance.font,
                    .foregroundColor: appearance.senderNameLabelAppearance.foregroundColor
                ]
            ))
        }
        result.append(NSAttributedString(
            string: message.body,
            attributes: [
                .font: appearance.subtitleLabelAppearance?.font ?? Fonts.regular.withSize(15),
                .foregroundColor: appearance.subtitleLabelAppearance?.foregroundColor ?? UIColor.secondaryText
            ]
        ))
        return result
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(avatarView)
        contentView.addSubview(timeLabel)
        contentView.addSubview(textVStack)
        contentView.addSubview(separatorView)

        avatarView.pin(to: contentView, anchors: [.leading(Layouts.horizontalPadding), .top(Layouts.verticalPadding)])
        avatarView.resize(anchors: [.height(Layouts.iconSize), .width(Layouts.iconSize)])

        timeLabel.pin(to: contentView, anchors: [.trailing(-Layouts.horizontalPadding), .top(Layouts.verticalPadding)])
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        textVStack.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: Layouts.horizontalPadding)
        textVStack.topAnchor.pin(to: contentView.topAnchor, constant: Layouts.verticalPadding)
        textVStack.trailingAnchor.pin(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -Layouts.timeLabelSpacing)

        separatorView.topAnchor.pin(greaterThanOrEqualTo: textVStack.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.topAnchor.pin(greaterThanOrEqualTo: avatarView.bottomAnchor, constant: Layouts.verticalPadding)
        separatorView.pin(to: contentView, anchors: [.bottom, .trailing(-Layouts.horizontalPadding)])
        separatorView.leadingAnchor.pin(to: titleLabel.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
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
        statusLabel.numberOfLines = 2
        timeLabel.textColor = appearance.dateLabelAppearance.foregroundColor
        timeLabel.font = appearance.dateLabelAppearance.font
    }

    override open func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        statusLabel.attributedText = nil
        timeLabel.text = nil
        imageTask?.cancel()
        messageData = nil
    }
}

public extension GlobalSearchMessageCell {
    enum Layouts {
        public static var iconSize: CGFloat = 56
        public static var verticalPadding: CGFloat = 8
        public static var horizontalPadding: CGFloat = 16
        public static var textSpacing: CGFloat = 3
        public static var timeLabelSpacing: CGFloat = 8
    }
}
