//
//  ChannelCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

extension ChannelListViewController {
    open class ChannelCell: TableViewCell {
        
        open lazy var badgeStackView = UIStackView(arrangedSubviews: [pinView, atView, unreadCount])
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)
        
        open lazy var messageStackView = UIStackView(arrangedSubviews: [subjectLabel, messageLabel])
            .withoutAutoresizingMask
        
        open lazy var unreadCount = Components.badgeView.init()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)
        
        open lazy var atView = Components.badgeView.init()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)
        
        open lazy var subjectLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.defaultLow)
        
        open lazy var muteView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.center)
        
        open lazy var avatarView = ImageView.init()
            .withoutAutoresizingMask
        
        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.defaultLow)
        
        open lazy var dateLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var pinView = UIImageView(image: appearance.pinIcon)
            .withoutAutoresizingMask
            .contentMode(.center)
        
        open lazy var ticksView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.center)
        
        open lazy var presenceView = UIImageView()
            .withoutAutoresizingMask
        
        lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        private var unreadCountWidthAnchorConstraint: NSLayoutConstraint?
        private var messageStackViewCenterYConstraint: NSLayoutConstraint?
        private var messageVerticalConstraints: [NSLayoutConstraint] = []
        
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
            muteView.image = appearance.mutedIcon
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
            
            let topConstraint = messageStackView.topAnchor.pin(to: contentView.topAnchor, constant: 10)
            let bottomConstraint = messageStackView.bottomAnchor.pin(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
            messageVerticalConstraints = [topConstraint, bottomConstraint]
            messageStackView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 12)
            messageStackView.trailingAnchor.pin(lessThanOrEqualTo: dateLabel.trailingAnchor)
            messageStackViewCenterYConstraint = messageStackView.centerYAnchor.pin(to: contentView.centerYAnchor, activate: false)
            updateCenterYConstraint()
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
            updateConstraint()
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            unreadCount.font = appearance.unreadCountLabelAppearance.font
            unreadCount.textColor = appearance.unreadCountLabelAppearance.foregroundColor
            atView.font = appearance.unreadMentionLabelAppearance.font
            atView.textColor = appearance.unreadMentionLabelAppearance.foregroundColor
            subjectLabel.font = appearance.subjectLabelAppearance.font
            subjectLabel.textColor = appearance.subjectLabelAppearance.foregroundColor
            
            
            dateLabel.clipsToBounds = true
            dateLabel.font = appearance.dateLabelAppearance.font
            dateLabel.textColor = appearance.dateLabelAppearance.foregroundColor
            separatorView.backgroundColor = appearance.separatorColor
        }
        
        private func updateConstraint() {
            if !unreadCount.isHidden {
                unreadCountWidthAnchorConstraint?.constant = 20
            }
        }
        
        private func update(messageText: NSAttributedString?) {
            messageLabel.attributedText = messageText
            updateCenterYConstraint()
        }
        
        private func updateCenterYConstraint() {
            let shouldCenter = messageLabel.attributedText?.string.isEmpty != false
            messageStackViewCenterYConstraint?.isActive = shouldCenter
            messageVerticalConstraints.forEach { $0.isActive = !shouldCenter }
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
            subjectLabel.text = data.formattedSubject
            update(messageText: data.attributedView)
            dateLabel.text = data.formattedDate
            pinView.isHidden = data.channel.pinnedAt == nil
            backgroundColor = data.channel.pinnedAt == nil ? .clear : appearance.backgroundColor
            ticksView.image = deliveryStatusImage(message: data.lastMessage)
            ticksView.isHidden = data.lastMessage?.state == .deleted
            unreadCount.value = data.formattedUnreadCount
            if unreadCount.isHidden, data.channel.unread {
                unreadCount.isHidden = false
            }
            muteView.isHidden = !data.channel.muted
            unreadCount.backgroundColor = !data.channel.muted ? appearance.unreadCountLabelAppearance.backgroundColor : appearance.unreadCountMutedStateLabelAppearance.backgroundColor
            unreadCount.textColor = !data.channel.muted ? appearance.unreadCountLabelAppearance.foregroundColor : appearance.unreadCountMutedStateLabelAppearance.foregroundColor
            atView.label.textColor = !data.channel.muted ? appearance.unreadMentionLabelAppearance.foregroundColor : appearance.unreadMentionMutedStateLabelAppearance.foregroundColor
            atView.backgroundColor = !data.channel.muted ? appearance.unreadMentionLabelAppearance.backgroundColor : appearance.unreadMentionMutedStateLabelAppearance.backgroundColor
            
            if data.channel.isDirect, let peer = data.channel.peer {
                presenceView.isHidden = peer.presence.state != .online
                presenceView.image = appearance.presenceStateIconProvider.provideVisual(for: peer.presence.state)
            } else {
                presenceView.isHidden = true
            }
            if data.channel.newMentionCount > 0,
               data.channel.newMessageCount > 0 {
                atView.value = SceytChatUIKit.shared.config.mentionTriggerPrefix
            } else {
                atView.value = nil
            }
            data.$avatar
                .sink { [weak self] image in
                    guard let self else { return }
                    avatarView.image = image
                    avatarView.shape = appearance.avatarAppearance.shape
                    avatarView.backgroundColor = appearance.avatarAppearance.backgroundColor
                    avatarView.clipsToBounds = true
                    avatarView.contentMode = .scaleAspectFill
                }.store(in: &subscriptions)
            updateConstraints()
        }
        
        open func deliveryStatusImage(message: ChatMessage?) -> UIImage? {
            guard let message = message, !message.incoming else { return nil }
            switch message.deliveryStatus {
            case .pending:
                return appearance.messageDeliveryStatusIcons.pendingIcon
            case .sent:
                return appearance.messageDeliveryStatusIcons.sentIcon
            case .received:
                return appearance.messageDeliveryStatusIcons.receivedIcon
            case .displayed:
                return appearance.messageDeliveryStatusIcons.displayedIcon
            case .failed:
                return appearance.messageDeliveryStatusIcons.failedIcon
            }
        }
                
        open func unreadCount(channel: ChatChannel) -> String? {
            appearance.unreadCountFormatter.format(channel.newMessageCount)
        }
        
        open func didStartTyping(member: ChatChannelMember) {
            let message = NSMutableAttributedString(string: "")
            if !data.channel.isDirect {
                message.append(NSAttributedString(
                    string: "\(Components.typingView.display(typer: appearance.typingUserNameFormatter.format(member), split: .firstWord)): ",
                    attributes: [
                        .font: appearance.lastMessageSenderNameLabelAppearance.font,
                        .foregroundColor: appearance.lastMessageSenderNameLabelAppearance.foregroundColor
                    ]
                ))
            }
            message.append(NSAttributedString(
                string: "\(L10n.Channel.Member.typing)...",
                attributes: [
                    .font: appearance.typingLabelAppearance.font,
                    .foregroundColor: appearance.typingLabelAppearance.foregroundColor]
            ))
            update(messageText: message)
            messageLabel.setNeedsLayout()
            messageLabel.layoutIfNeeded()
        }
        
        open func didStopTyping(member: ChatChannelMember) {
            update(messageText: data.attributedView)
            messageLabel.setNeedsLayout()
            messageLabel.layoutIfNeeded()
        }
        
        open func subscribeForPresence() {
            guard data.channel.isDirect,
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
                    self.bind(self.data)
                }
            }
        }
        
        open func unsubscribeFromPresence(data: ChannelLayoutModel) {
            guard data.channel.isDirect,
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
}

public extension ChannelListViewController.ChannelCell {
    enum Layouts {
        public static var avatarSize: CGFloat = 56
        public static var horizontalPadding: CGFloat = 16
        public static var verticalPadding: CGFloat = 12
    }
}
