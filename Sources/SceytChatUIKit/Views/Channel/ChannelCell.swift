//
//  ChannelCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

open class ChannelCell: TableViewCell {
    
    open lazy var badgeStackView = UIStackView(arrangedSubviews: [atView, unreadCount])
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.required)
    
    open lazy var messageStackView = UIStackView(arrangedSubviews: [subjectLabel, messageLabel])
        .withoutAutoresizingMask
      
    open lazy var unreadCount = BadgeView()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.required)
    
    open lazy var atView = BadgeView()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.required)

    open lazy var subjectLabel = UILabel()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.defaultLow)

    open lazy var muteView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.center)

    open lazy var avatarView = CircleImageView()
        .withoutAutoresizingMask

    open lazy var messageLabel = UILabel()
        .withoutAutoresizingMask
        .contentCompressionResistancePriorityH(.defaultLow)

    open lazy var dateLabel = UILabel()
        .withoutAutoresizingMask

    open lazy var ticksView = UIImageView()
        .withoutAutoresizingMask
        .contentMode(.center)

    open lazy var presenceView = UIImageView()
        .withoutAutoresizingMask

    lazy var separatorView = UIView()
        .withoutAutoresizingMask

    private var unreadCountWidthAnchorConstraint: NSLayoutConstraint?

    override open func prepareForReuse() {
        super.prepareForReuse()
        subscriptions.removeAll(keepingCapacity: true)
    }

    @objc
    private func panGestureAction(_ sender: UIPanGestureRecognizer) {
        isSelected = false
    }

    override open func setup() {
        super.setup()
        messageStackView.axis = .vertical
        messageStackView.distribution = .fill
        messageStackView.alignment = .leading
        messageStackView.spacing = 2
        
        badgeStackView.axis = .horizontal
        badgeStackView.distribution = .fill
        badgeStackView.alignment = .trailing
        badgeStackView.spacing = 8
        
        messageLabel.numberOfLines = 2
        muteView.image = .mute
        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(panGestureAction(_:))
        )
        pan.delegate = self
        addGestureRecognizer(pan)
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(messageStackView)
        contentView.addSubview(badgeStackView)
        contentView.addSubview(muteView)
        contentView.addSubview(avatarView)
        contentView.addSubview(dateLabel)
        contentView.addSubview(ticksView)
        contentView.addSubview(presenceView)
        contentView.addSubview(separatorView)

        avatarView.pin(to: contentView, anchors: [
            .top(8, .greaterThanOrEqual),
            .centerY(),
            .leading(Layouts.horizontalPadding)
        ])
        avatarView.resize(anchors: [.width(Layouts.avatarSize), .height(Layouts.avatarSize)])

        presenceView.pin(to: avatarView, anchors: [
            .trailing(),
            .bottom(-2)
        ])

        messageStackView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 12)
        messageStackView.bottomAnchor.pin(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
        messageStackView.trailingAnchor.pin(lessThanOrEqualTo: dateLabel.trailingAnchor)
        messageStackView.topAnchor.pin(to: contentView.topAnchor, constant: 10)
        messageLabel.trailingAnchor.pin(lessThanOrEqualTo: dateLabel.trailingAnchor)
        messageLabel.trailingAnchor.pin(lessThanOrEqualTo: badgeStackView.leadingAnchor)
        muteView.centerYAnchor.pin(to: subjectLabel.centerYAnchor)
        muteView.leadingAnchor.pin(to: subjectLabel.trailingAnchor, constant: 4)
        ticksView.leadingAnchor.pin(greaterThanOrEqualTo: subjectLabel.trailingAnchor, constant: 8)
        ticksView.leadingAnchor.pin(greaterThanOrEqualTo: muteView.trailingAnchor, constant: 2)
        ticksView.trailingAnchor.pin(to: dateLabel.leadingAnchor, constant: -4)
        ticksView.centerYAnchor.pin(to: dateLabel.centerYAnchor)

        dateLabel.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -Layouts.horizontalPadding)
        dateLabel.centerYAnchor.pin(to: subjectLabel.centerYAnchor)

        badgeStackView.trailingAnchor.pin(to: dateLabel.trailingAnchor)
        badgeStackView.topAnchor.pin(to: dateLabel.bottomAnchor, constant: 2)
        unreadCount.heightAnchor.pin(constant: 20)
        unreadCountWidthAnchorConstraint = unreadCount.widthAnchor.pin(greaterThanOrEqualToConstant: 20)
        atView.resize(anchors: [.height(20), .width(20)])
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing(-Layouts.horizontalPadding)])
        separatorView.leadingAnchor.pin(to: messageStackView.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
        updateMessageLabelTrailingAnchor()
    }

    override open func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = appearance.backgroundColor
        unreadCount.font = appearance.unreadCountFont
        unreadCount.textColor = appearance.unreadCountTextColor
        atView.font = appearance.unreadCountFont
        atView.textColor = appearance.unreadCountTextColor
        subjectLabel.textColor = appearance.subjectLabelTextColor
        subjectLabel.font = appearance.subjectLabelFont
        
        dateLabel.clipsToBounds = true
        dateLabel.textColor = appearance.dateLabelTextColor
        dateLabel.font = appearance.dateLabelFont
        presenceView.image = .online
        separatorView.backgroundColor = appearance.separatorColor
    }

    private func updateMessageLabelTrailingAnchor() {
        if !unreadCount.isHidden {
            unreadCountWidthAnchorConstraint?.constant = 20
        }
    }

    open var data: ChannelLayoutModel! {
        didSet {
            guard let data = data
            else { return }
            bind(data)
            subscribeForPresence()
        }
    }

    open func bind(_ data: ChannelLayoutModel) {
        subjectLabel.text = data.formatedSubject
        messageLabel.attributedText = data.attributedView
        dateLabel.text = data.formatedDate
        ticksView.tintColor = deliveryStatusColor(message: data.lastMessage)
        ticksView.image = deliveryStatusImage(message: data.lastMessage)?.withRenderingMode(.alwaysTemplate)
        ticksView.isHidden = data.lastMessage?.state == .deleted
        unreadCount.value = data.formatedUnreadCount
        if unreadCount.isHidden, data.channel.unread {
            unreadCount.isHidden = false
        }
        muteView.isHidden = !data.channel.muted
        unreadCount.backgroundColor = !data.channel.muted ? appearance.unreadCountBackgroundColor : appearance.unreadCountMutedBackgroundColor
        atView.backgroundColor = !data.channel.muted ? appearance.unreadCountBackgroundColor : appearance.unreadCountMutedBackgroundColor

        if !data.channel.isGroup, let peer = data.channel.peer {
            presenceView.isHidden = peer.presence.state != .online
        } else {
            presenceView.isHidden = true
        }
        if data.channel.newMentionCount > 0,
            data.channel.newMessageCount > 0 {
            atView.value = Config.mentionSymbol
        } else {
            atView.value = nil
        }
        data.$avatar
            .sink {[weak self] image in
                self?.avatarView.image = image
            }.store(in: &subscriptions)
        updateMessageLabelTrailingAnchor()
    }
    
    open func deliveryStatusImage(message: ChatMessage?) -> UIImage? {
        guard let message = message, !message.incoming else { return nil }
        switch message.deliveryStatus {
        case .pending:
            return .pendingMessage
        case .sent:
            return .sentMessage
        case .received:
            return .deliveredMessage
        case .displayed:
            return .readMessage
        case .failed:
            return .failedMessage
        }
    }
    
    open func deliveryStatusColor(message: ChatMessage?) -> UIColor? {
        guard let message = message, !message.incoming else { return nil }
        switch message.deliveryStatus {
        case .pending:
            return appearance.ticksViewDisabledTintColor
        case .sent:
            return appearance.ticksViewDisabledTintColor
        case .received:
            return appearance.ticksViewDisabledTintColor
        case .displayed:
            return appearance.ticksViewTintColor
        case .failed:
            return appearance.ticksViewErrorTintColor
        }
    }

    open func unreadCount(channel: ChatChannel) -> String? {
        Formatters
            .channelUnreadMessageCount
            .format(channel.newMessageCount)
    }
    
    open func didStartTyping(member: ChatChannelMember) {
        let message = NSMutableAttributedString(string: "")
        if data.channel.isGroup {
            message.append(NSAttributedString(
                string: "\(Components.typingView.display(typer: Formatters.userDisplayName.format(member), split: .firstWord)): ",
                attributes: [.font: appearance.senderLabelFont ?? Fonts.regular.withSize(15), .foregroundColor: appearance.senderLabelTextColor ?? .textBlack]
            ))
        }
        message.append(NSAttributedString(
            string: "\(L10n.Channel.Member.typing)...",
            attributes: [.font: appearance.typingFont ?? Fonts.regular.with(traits: .traitItalic).withSize(15), .foregroundColor: appearance.typingTextColor ?? .textGray]
        ))
        messageLabel.attributedText = message
        messageLabel.setNeedsLayout()
        messageLabel.layoutIfNeeded()
    }

    open func didStopTyping(member: ChatChannelMember) {
        messageLabel.attributedText = data.attributedView
        messageLabel.setNeedsLayout()
        messageLabel.layoutIfNeeded()
    }

    open func subscribeForPresence() {
        guard !data.channel.isGroup,
              let peer = data.channel.peer,
              peer.state == .active
        else {
            presenceView.isHidden = true
            return
        }
        Components.presenceProvider.subscribe(userId: peer.id) { [weak self] userPresence in
            guard let self, peer.id == self.data.channel.peer?.id
            else { return }
            self.presenceView.isHidden = userPresence.presence.state != .online
            let chatUser = ChatUser(user: userPresence.user)
            if chatUser !~= peer {
                self.data.updateMemberWithUser(chatUser)
                self.bind(data)
            }
        }
    }

    open func unsubscribeFromPresence(data: ChannelLayoutModel) {
        guard !data.channel.isGroup,
                let userId = data.channel.peer?.id
        else {
            presenceView.isHidden = true
            return
        }
        Components.presenceProvider.unsubscribe(userId: userId)
    }

    override open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        true
    }
}

public extension ChannelCell {
    enum Layouts {
        public static var avatarSize: CGFloat = 56
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 12
    }
}
