//
//  ChannelCell.swift
//  SceytChatUIKit
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

    open var imageTask: Cancellable?

    private var unreadCountWidthAnchorConstraint: NSLayoutConstraint?

    override open func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
    }

    @objc
    private func panGestureAction(_ sender: UIPanGestureRecognizer) {
        isSelected = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override open func setup() {
        super.setup()
        messageStackView.axis = .vertical
        messageStackView.distribution = .fill
        messageStackView.alignment = .leading
        
        badgeStackView.axis = .horizontal
        badgeStackView.distribution = .fill
        badgeStackView.alignment = .trailing
        badgeStackView.spacing = 8
        
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
            .leading(12)
        ])
        contentView.bottomAnchor.pin(greaterThanOrEqualTo: avatarView.bottomAnchor, constant: 7)
        avatarView.resize(anchors: [.width(60), .height(60)])

        presenceView.pin(to: avatarView, anchors: [
            .trailing(),
            .bottom()
        ])

        messageStackView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10)
        messageStackView.bottomAnchor.pin(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
        messageStackView.trailingAnchor.pin(lessThanOrEqualTo: dateLabel.trailingAnchor)
        messageStackView.topAnchor.pin(to: contentView.topAnchor, constant: 10)
        messageLabel.trailingAnchor.pin(lessThanOrEqualTo: dateLabel.trailingAnchor)
        messageLabel.trailingAnchor.pin(lessThanOrEqualTo: badgeStackView.leadingAnchor)
        muteView.centerYAnchor.pin(to: subjectLabel.centerYAnchor)
        muteView.leadingAnchor.pin(to: subjectLabel.trailingAnchor, constant: 4)
        ticksView.leadingAnchor.pin(greaterThanOrEqualTo: subjectLabel.trailingAnchor, constant: 8)
        ticksView.trailingAnchor.pin(to: dateLabel.leadingAnchor, constant: -5)
        ticksView.centerYAnchor.pin(to: dateLabel.centerYAnchor)

        dateLabel.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -12)
        dateLabel.centerYAnchor.pin(to: subjectLabel.centerYAnchor)

        badgeStackView.trailingAnchor.pin(to: dateLabel.trailingAnchor)
        badgeStackView.topAnchor.pin(to: dateLabel.bottomAnchor, constant: 13)
        unreadCount.heightAnchor.pin(constant: 20)
        unreadCountWidthAnchorConstraint = unreadCount.widthAnchor.pin(greaterThanOrEqualToConstant: 20)
        atView.resize(anchors: [.height(20), .width(20)])
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing()])
        separatorView.leadingAnchor.pin(to: messageStackView.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
        updateMessageLabelTrailingAnchor()
    }

    override open func setupAppearance() {
        super.setupAppearance()
        contentView.backgroundColor = appearance.backgroundColor
        unreadCount.backgroundColor = appearance.unreadCountBackgroundColor
        unreadCount.font = appearance.unreadCountFont
        unreadCount.textColor = appearance.unreadCountTextColor
        atView.backgroundColor = appearance.unreadCountBackgroundColor
        atView.font = appearance.unreadCountFont
        atView.textColor = appearance.unreadCountTextColor
        subjectLabel.textColor = appearance.subjectLabelTextColor
        subjectLabel.font = appearance.subjectLabelFont
        muteView.image = .mute
        messageLabel.numberOfLines = 2
        messageLabel.textColor = appearance.messageLabelTextColor
        messageLabel.font = appearance.messageLabelFont
        dateLabel.clipsToBounds = true
        dateLabel.textColor = appearance.dateLabelTextColor
        dateLabel.font = appearance.dateLabelFont
        ticksView.tintColor = appearance.ticksViewTintColor
        presenceView.image = .online
        separatorView.backgroundColor = appearance.separatorColor
    }

    private func updateMessageLabelTrailingAnchor() {
        if !unreadCount.isHidden {
            unreadCountWidthAnchorConstraint?.constant = 20
        }
    }

    open var data: ChatChannel! {
        didSet {
            guard let data = data else { return }
            bind(data)
        }
    }

    func bind(_ data: ChatChannel) {
        subjectLabel.text = Formatters.channelDisplayName.format(data)
        messageLabel.attributedText = message(channel: data)

        dateLabel.text = Formatters.channelTimestamp
            .format(
                ((data.lastMessage?.updatedAt ?? data.lastMessage?.createdAt) ?? data.updatedAt) ?? data.createdAt
            )
        ticksView.image = deliveryStatusImage(message: data.lastMessage)?.withRenderingMode(.alwaysOriginal)
        ticksView.isHidden = data.lastMessage?.state == .deleted
        unreadCount.value = unreadCount(channel: data)
        if unreadCount.isHidden, data.markedAsUnread {
            unreadCount.isHidden = false
        }
        muteView.isHidden = !data.muted

        if data.type == .direct, let peer = data.peer {
            presenceView.isHidden = peer.presence.state != .online
        } else {
            presenceView.isHidden = true
        }
        if data.unreadMentionCount > 0 {
            atView.value = "@"
        } else {
            atView.value = nil
        }
        imageTask = Components.avatarBuilder.loadAvatar(into: avatarView.imageView, for: data)
        updateMessageLabelTrailingAnchor()
    }

    open func message(channel: ChatChannel) -> NSAttributedString {
        guard let message = channel.lastMessage
        else { return NSAttributedString() }
        if let text = createDraftMessageIfNeeded(channel: channel) {
            return text
        }
        let attributedMessage = Components.messageLayoutModel.attributedView(
            message: message,
            multiLine: false,
            bodyFont: appearance.messageLabelFont ?? Fonts.regular.withSize(16),
            bodyColor: appearance.messageLabelTextColor ?? Colors.textBlack,
            linkMentionedItem: false
        )

        if let attachment = message.attachments?.last {
            var icon: UIImage?
            var type: String?
            switch attachment.type {
            case "file":
                icon = Images.attachmentFile
                type = L10n.Attachment.file
            case "image":
                icon = Images.attachmentImage
                type = L10n.Attachment.image
            case "video":
                icon = Images.attachmentVideo
                type = L10n.Attachment.video
            case "voice":
                icon = Images.attachmentVoice
                type = L10n.Attachment.voice
            default:
                break
            }
            if let icon, let type {
                let font = Fonts.regular.withSize(15)
                let attachment = NSTextAttachment()
                attachment.bounds = CGRect(x: 0, y: (font.capHeight - icon.size.height).rounded() / 2, width: icon.size.width, height: icon.size.height)
                attachment.image = icon
                let attributedAttachmentMessage = NSMutableAttributedString(attachment: attachment)
                attributedAttachmentMessage.append(NSAttributedString(
                    string: " ",
                    attributes: [.font: font]
                ))
                if attributedMessage.isEmpty {
                    attributedAttachmentMessage.append(NSAttributedString(
                        string: type,
                        attributes: [.font: font]
                    ))
                } else {
                    attributedAttachmentMessage.append(attributedMessage)
                }
                return attributedAttachmentMessage
            } else {
                return attributedMessage
            }
        }
        return attributedMessage
    }
    
    open func createDraftMessageIfNeeded(channel: ChatChannel) -> NSAttributedString? {
        guard let draft = channel.draftMessage,
              draft.length > 0
        else { return nil }
        
        let text = NSMutableAttributedString()
        let title = L10n.Channel.Message.draft
        let draftString = NSMutableAttributedString(string: "\(title)\n")
        draftString.addAttributes(
            [.foregroundColor: appearance.draftMessageTitleColor as Any,
             .font: appearance.draftMessageTitleFont as Any],
            range: NSMakeRange(0, title.count))
        text.append(draftString)
        
        let contentString = NSMutableAttributedString(attributedString: draft)
        contentString.addAttributes(
            [.foregroundColor: appearance.draftMessageContentColor as Any,
             .font: appearance.draftMessageContentFont as Any ],
            range: NSMakeRange(0, draft.length))
        text.append(contentString)
        return text
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

    open func unreadCount(channel: ChatChannel) -> String? {
        Formatters
            .channelUnreadMessageCount
            .format(channel.unreadMessageCount)
    }
    
    open func didStartTyping(member: ChatChannelMember) {
        var message = ""
        if data.type.isGroup {
            message = "\(TypingView.display(typer: Formatters.userDisplayName.format(member))) "
        }
        message.append("\(L10n.Channel.Member.typing)...")
        messageLabel.attributedText = NSAttributedString(
            string: message,
            attributes: [.font: appearance.typingFont as Any, .foregroundColor: appearance.typingTextColor as Any]
        )
        messageLabel.setNeedsLayout()
    }

    open func didStopTyping(member: ChatChannelMember) {
        messageLabel.attributedText = message(channel: data)
        messageLabel.setNeedsLayout()
    }

    open func subscribeForPresence() {
        guard data.type == .direct,
              let peer = data.peer,
              peer.activityState == .active
        else {
            presenceView.isHidden = true
            return
        }
        PresenceProvider.subscribe(userId: peer.id) { [weak self] userPresence in
            guard let self, peer.id == self.data.peer?.id
            else { return }
            self.presenceView.isHidden = userPresence.presence.state != .online
            if userPresence.user.avatarUrl != self.data.peer?.avatarUrl {
                self.imageTask?.cancel()
                self.imageTask = Components.avatarBuilder.loadAvatar(into: self.avatarView.imageView, for: self.data)
            }
        }
    }

    open func unsubscribeFromPresence() {
        guard data.type == .direct, let userId = data.peer?.id
        else {
            presenceView.isHidden = true
            return
        }
        PresenceProvider.unsubscribe(userId: userId)
    }

    override open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        true
    }
}
