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
        
        // MARK: - Stack hierarchy
        //
        // contentStackView (H)
        // ├─ avatarContainer                  (avatar + presence / retention overlays)
        // └─ rightStackView (V)
        //    ├─ topRowStackView (H)           [ subjectStackView ──spacer── dateStackView ]
        //    │  ├─ subjectStackView (H)        [ subjectLabel  muteView  «spacer» ]
        //    │  └─ dateStackView (H)           [ ticksView  dateLabel ]
        //    └─ bottomRowStackView (H)        [ messageLabel ──spacer── badgeStackView ]
        //       └─ badgeStackView (H)          [ atView  unreadCount pinView ]

        open lazy var contentStackView = UIStackView(arrangedSubviews: [avatarContainer, rightStackView])
            .withoutAutoresizingMask

        /// Non-clipping host for the avatar so the presence / retention badges
        /// can extend beyond the (clipped) avatar image.
        open lazy var avatarContainer = UIView()
            .withoutAutoresizingMask

        open lazy var rightStackView = UIStackView(arrangedSubviews: [topRowStackView, bottomRowStackView])
            .withoutAutoresizingMask

        /// Top row: subject (left, expands) + date (right, fixed size).
        open lazy var topRowStackView = UIStackView(arrangedSubviews: [subjectStackView, dateStackView])
            .withoutAutoresizingMask

        /// Bottom row: message preview (left, expands) + badges (right).
        open lazy var bottomRowStackView = UIStackView(arrangedSubviews: [messageLabel, badgeStackView])
            .withoutAutoresizingMask

        open lazy var subjectStackView = UIStackView(arrangedSubviews: [subjectLabel, muteView, subjectSpacerView])
            .withoutAutoresizingMask

        /// Date column: ticks + timestamp, kept at its intrinsic size and pinned
        /// to the trailing edge of the top row.
        open lazy var dateStackView = UIStackView(arrangedSubviews: [ticksView, dateLabel])
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)
            .contentCompressionResistancePriorityH(.required)

        /// Badges. Sized strictly to their content (required hugging +
        /// compression resistance), so the row gives the badges exactly the
        /// width they need and lets `messageLabel` take the rest.
        open lazy var badgeStackView = UIStackView(arrangedSubviews: [atView, unreadCount, pinView])
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)
            .contentCompressionResistancePriorityH(.required)

        /// Flexible spacer that keeps `muteView` next to the subject text instead
        /// of being pushed to the trailing edge of the filled subject row.
        open lazy var subjectSpacerView = UIView()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(UILayoutPriority(1))

        // MARK: - Components

        open lazy var unreadCount = Components.badgeLabel.init()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)
            .contentCompressionResistancePriorityH(.required)

        open lazy var atView = Components.badgeLabel.init()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)
            .contentCompressionResistancePriorityH(.required)
        
        open lazy var subjectLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.defaultLow)
        
        open lazy var muteView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFit)
        
        open lazy var avatarView = ImageView.init()
            .withoutAutoresizingMask
        
        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.defaultLow)
            .contentCompressionResistancePriorityH(.defaultLow)
        
        open lazy var dateLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var pinView = UIImageView(image: appearance.pinIcon)
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFit)
        
        open lazy var ticksView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFit)
        
        open lazy var presenceView = UIImageView()
            .withoutAutoresizingMask
        
        open lazy var retentionBadgeView = UIImageView()
            .withoutAutoresizingMask
        
        lazy var separatorView = UIView()
            .withoutAutoresizingMask

        public var eventModels: [ChannelEventModel] = []
        private var updateTimer: Timer?

        /// Size constraints for the delivery-status tick, recomputed for the
        /// current Dynamic Type category so the icon scales with the date label.
        private var ticksWidthConstraint: NSLayoutConstraint?
        private var ticksHeightConstraint: NSLayoutConstraint?

        /// Size constraints for the pin icon, recomputed for the current Dynamic
        /// Type category so the icon scales alongside the unread badge.
        private var pinWidthConstraint: NSLayoutConstraint?
        private var pinHeightConstraint: NSLayoutConstraint?
        
        override open func prepareForReuse() {
            super.prepareForReuse()
            clearEvents()
            subscriptions.removeAll(keepingCapacity: true)
        }
        
        override open func setup() {
            super.setup()
            backgroundView = UIView()

            contentStackView.axis = .horizontal
            contentStackView.distribution = .fill
            // Top-align so the subject row stays pinned to the top of the cell.
            // The avatar (the tallest item) drives the stack's constant height, so
            // it still reads as centered, while the message preview grows downward
            // instead of shifting the subject up/down as its line count changes.
            contentStackView.alignment = .top
            contentStackView.spacing = 12

            rightStackView.axis = .vertical
            rightStackView.distribution = .fill
            rightStackView.alignment = .fill
            rightStackView.spacing = Layouts.messageStackSpacing

            topRowStackView.axis = .horizontal
            topRowStackView.distribution = .fill
            topRowStackView.alignment = .center
            topRowStackView.spacing = 8

            bottomRowStackView.axis = .horizontal
            bottomRowStackView.distribution = .fill
            bottomRowStackView.alignment = .top
            bottomRowStackView.spacing = 8

            subjectStackView.axis = .horizontal
            subjectStackView.distribution = .fill
            subjectStackView.alignment = .center
            subjectStackView.spacing = 4

            dateStackView.axis = .horizontal
            dateStackView.distribution = .fill
            dateStackView.alignment = .center
            dateStackView.spacing = 4

            badgeStackView.axis = .horizontal
            badgeStackView.distribution = .fill
            badgeStackView.alignment = .trailing
            badgeStackView.spacing = 8

            messageLabel.numberOfLines = Layouts.messagePreviewNumberOfLines
            messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            muteView.image = appearance.mutedIcon

            // Re-scale the (UIFontMetrics-based) fonts live when the user changes
            // the Dynamic Type / Large Text setting, instead of only after an app
            // relaunch. The row height is recomputed for the new category in
            // ChannelListViewController.traitCollectionDidChange.
            [subjectLabel, messageLabel, dateLabel, unreadCount, atView]
                .forEach { $0.adjustsFontForContentSizeCategory = true }
        }
        
        override open func setupLayout() {
            super.setupLayout()

            // Avatar + overlapping presence / retention badges. They sit in a
            // dedicated container (not the avatar itself, which clips its rounded
            // image) so the badges can extend slightly past the avatar edges.
            avatarContainer.addSubview(avatarView)
            avatarContainer.addSubview(presenceView)
            avatarContainer.addSubview(retentionBadgeView)
            avatarView.pin(to: avatarContainer)
            avatarView.resize(anchors: [.width(Layouts.avatarSize), .height(Layouts.avatarSize)])

            presenceView.pin(to: avatarView, anchors: [
                .trailing(),
                .bottom(-2)
            ])

            retentionBadgeView.pin(to: avatarView, anchors: [
                .trailing(4),
                .top(-4)
            ])
            retentionBadgeView.resize(anchors: [.width(22), .height(22)])

            contentView.addSubview(contentStackView)
            contentView.addSubview(separatorView)

            // Pin the content to the top so the subject row is fixed there. The
            // cell height is a constant sized for a full preview, and the avatar
            // is the tallest item, so a top inset of avatarVerticalPadding leaves
            // the avatar exactly where centering used to put it — while the
            // message preview now grows downward instead of shifting the subject.
            contentStackView.pin(to: contentView, anchors: [
                .leading(Layouts.horizontalPadding),
                .top(Layouts.avatarVerticalPadding)
            ])
            contentStackView.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -Layouts.horizontalPadding)
            // Fixed bottom: the cell height is a constant, so the content fills the
            // vertical area exactly (8…56…8). With `.top` alignment the avatar fills
            // it and the subject stays pinned to the top.
            contentStackView.bottomAnchor.pin(to: contentView.bottomAnchor, constant: -Layouts.avatarVerticalPadding)

            // The pin icon has no fixed size: it's driven by these constraints,
            // recomputed from a 20pt square base scaled for the current Dynamic
            // Type category (see updatePinViewSize). It sizes itself rather than
            // tracking the unread badge so that hiding it (unpinned channels)
            // only collapses the pin's own width inside the stack — it can't drag
            // the unread/mention badges down to zero height.
            pinWidthConstraint = pinView.widthAnchor.pin(constant: 0)
            pinHeightConstraint = pinView.heightAnchor.pin(constant: 0)

            // The tick has no fixed size: it's driven by these constraints, which
            // are recomputed from the icon's intrinsic size scaled for the current
            // Dynamic Type category (see updateTicksViewSize).
            ticksWidthConstraint = ticksView.widthAnchor.pin(constant: 0)
            ticksHeightConstraint = ticksView.heightAnchor.pin(constant: 0)

            atView.heightAnchor.pin(to: unreadCount.heightAnchor).isActive = true

            separatorView.pin(to: contentView, anchors: [.bottom(), .trailing(-Layouts.horizontalPadding)])
            separatorView.leadingAnchor.pin(to: rightStackView.leadingAnchor)
            separatorView.heightAnchor.pin(constant: 1)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            backgroundView?.backgroundColor = appearance.backgroundColor
            unreadCount.font = appearance.unreadCountLabelAppearance.font
            unreadCount.textColor = appearance.unreadCountLabelAppearance.foregroundColor
            atView.font = appearance.unreadMentionLabelAppearance.font
            atView.textColor = appearance.unreadMentionLabelAppearance.foregroundColor
            subjectLabel.font = appearance.subjectLabelAppearance.font
            subjectLabel.textColor = appearance.subjectLabelAppearance.foregroundColor

            retentionBadgeView.image = appearance.retentionBadgeImage
            retentionBadgeView.contentMode = .scaleAspectFit
            retentionBadgeView.layer.borderColor = DefaultColors.background.resolvedColor(with: traitCollection).cgColor
            retentionBadgeView.layer.borderWidth = 2
            retentionBadgeView.layer.cornerRadius = 11
            retentionBadgeView.clipsToBounds = true
            
            dateLabel.clipsToBounds = true
            dateLabel.font = appearance.dateLabelAppearance.font
            dateLabel.textColor = appearance.dateLabelAppearance.foregroundColor
            separatorView.backgroundColor = appearance.separatorColor
            retentionBadgeView.isHidden = true
            pinView.isHidden = true
            muteView.isHidden = true
        }

        override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)

            if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
                retentionBadgeView.layer.borderColor = DefaultColors.background.resolvedColor(with: traitCollection).cgColor
            }

            // Large Text changed: grow/shrink the tick and pin alongside their
            // neighboring labels/badges.
            if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
                updateTicksViewSize()
                updatePinViewSize()
            }
        }

        /// Scales the delivery-status tick with Dynamic Type.
        ///
        /// The base size is the icon's own intrinsic size, scaled by the same
        /// factor the date label uses (its text style), so the tick keeps its
        /// design size at the default Large Text setting and grows proportionally
        /// from there — staying visually aligned with the date next to it.
        open func updateTicksViewSize() {
            guard let size = ticksView.image?.size, size != .zero else { return }
            let style = UIFont.preferredTextStyle(for: appearance.dateLabelAppearance.baseFont.pointSize)
            let metrics = UIFontMetrics(forTextStyle: style)
            ticksWidthConstraint?.constant = metrics.scaledValue(for: size.width, compatibleWith: traitCollection)
            ticksHeightConstraint?.constant = metrics.scaledValue(for: size.height, compatibleWith: traitCollection)
        }

        /// Scales the pin icon with Dynamic Type.
        ///
        /// Keeps the icon a 20pt square at the default Large Text setting (its
        /// original design size) and grows it proportionally from there, using
        /// the same text style as the unread badge so the two stay visually
        /// aligned in the badge row.
        open func updatePinViewSize() {
            let base: CGFloat = 20
            let style = UIFont.preferredTextStyle(for: appearance.unreadCountLabelAppearance.baseFont.pointSize)
            let metrics = UIFontMetrics(forTextStyle: style)
            let scaled = metrics.scaledValue(for: base, compatibleWith: traitCollection)
            pinWidthConstraint?.constant = scaled
            pinHeightConstraint?.constant = scaled
        }

        // MARK: - Event Management Methods
        private func addEvent(_ event: ChannelEventView.Event, for user: ChatUser) {
            let model = ChannelEventModel(
                user: user,
                event: event,
                indicatorConfiguration: .indicator()
            )
            
            if !eventModels.contains(where: { $0.user.id == model.user.id && $0.event == model.event }) {
                eventModels.append(model)
            }
            
            // Start timer if not already running
            if updateTimer == nil {
                updateNextAction()
                startDisplayTimer()
            }
        }
        
        private func startDisplayTimer() {
            updateTimer?.invalidate()
            
            updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.updateNextAction()
            }
        }
        
        private func stopDisplayTimer() {
            updateTimer?.invalidate()
            updateTimer = nil
        }
        
        // MARK: - Public Methods for External Use
        
        private func removeEvent(for userId: UserId) {
            eventModels.removeAll { $0.user.id == userId }

            if eventModels.isEmpty {
                stopDisplayTimer()
                // Guard against nil data during cell recycling/observer restart
                guard let data = data else { return }
                update(messageText: data.attributedView)
            }
        }
        
        private func showTypingIndicator(for user: ChatUser) {
            addEvent(.typing, for: user)
        }
        
        private func showRecordingIndicator(for user: ChatUser) {
            addEvent(.recording, for: user)
        }
        
        private func hideIndicator(for userId: UserId) {
            removeEvent(for: userId)
        }
        
        public func update(messageText: NSAttributedString?) {
            messageLabel.attributedText = messageText
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
            updatePinViewSize()
            backgroundColor = data.channel.pinnedAt == nil ? .clear : appearance.backgroundColor
            backgroundView?.backgroundColor = appearance.backgroundColor
            
            ticksView.image = deliveryStatusImage(message: data.lastMessage)
            ticksView.isHidden = !data.shouldShowDeliveryTick
            updateTicksViewSize()
            // Show the unread badge when there are unread messages (a count to
            // display) or the channel was manually marked as unread (empty dot).
            unreadCount.value = data.formattedUnreadCount
            let hasUnreadCount = !(data.formattedUnreadCount?.isEmpty ?? true)
            unreadCount.isHidden = !(hasUnreadCount || data.channel.unread)
            muteView.isHidden = !data.channel.muted
            unreadCount.backgroundColor = !data.channel.muted ? appearance.unreadCountLabelAppearance.backgroundColor : appearance.unreadCountMutedStateLabelAppearance.backgroundColor
            unreadCount.textColor = !data.channel.muted ? appearance.unreadCountLabelAppearance.foregroundColor : appearance.unreadCountMutedStateLabelAppearance.foregroundColor
            atView.textColor = !data.channel.muted ? appearance.unreadMentionLabelAppearance.foregroundColor : appearance.unreadMentionMutedStateLabelAppearance.foregroundColor
            atView.backgroundColor = !data.channel.muted ? appearance.unreadMentionLabelAppearance.backgroundColor : appearance.unreadMentionMutedStateLabelAppearance.backgroundColor
            
            if data.channel.isDirect, let peer = data.channel.peer {
                presenceView.isHidden = peer.presence.state != .online
                presenceView.image = appearance.presenceStateIconProvider.provideVisual(for: peer.presence.state)
            } else {
                presenceView.isHidden = true
            }
            
            // Show retention badge if messageRetentionPeriod > 0
            retentionBadgeView.isHidden = data.channel.messageRetentionPeriod <= 0
            
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
                    avatarView.clipsToBounds = true
                    avatarView.contentMode = .scaleAspectFill
                }.store(in: &subscriptions)
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
        
        open func updateNextAction() {
            guard !eventModels.isEmpty else {
                clearEvents()
                return
            }
            
            // Get current event to display
            let currentModel = eventModels.removeFirst()
            
            // Build attributed text using priority models
            let attributedMessage = buildAttributedMessage(for: [currentModel])
            update(messageText: attributedMessage)

        }

        open func clearEvents() {
            eventModels.removeAll()
            stopDisplayTimer()

            // Guard against nil data during cell recycling/observer restart
            guard let data = data else { return }
            update(messageText: data.attributedView)
        }
        
        open func buildAttributedMessage(for models: [ChannelEventModel]) -> NSAttributedString {
            guard let model = models.first else {
                return data?.attributedView ?? NSAttributedString()
            }

            // Guard against nil data during cell recycling/observer restart
            guard let data = data else {
                return NSAttributedString()
            }

            let message = NSMutableAttributedString()

            if !data.channel.isDirect {
                let userName = appearance.typingUserNameFormatter.format(model.user)
                let nameAttributes: [NSAttributedString.Key: Any] = [
                    .font: appearance.lastMessageSenderNameLabelAppearance.font,
                    .foregroundColor: appearance.lastMessageSenderNameLabelAppearance.foregroundColor
                ]
                message.append(NSAttributedString(string: "\(userName): ", attributes: nameAttributes))
            }

            let actionAttributes: [NSAttributedString.Key: Any] = [
                .font: appearance.typingLabelAppearance.font,
                .foregroundColor: appearance.typingLabelAppearance.foregroundColor
            ]
            message.append(NSAttributedString(string: "\(model.event.title)...", attributes: actionAttributes))

            return message
        }
        
        open func didStartTyping(user: ChatUser) {
            showTypingIndicator(for: user)
        }
        
        open func didStopTyping(user: ChatUser) {
            hideIndicator(for: user.id)
        }
        
        open func didStartRecording(user: ChatUser) {
            showRecordingIndicator(for: user)
        }
        
        open func didStopRecording(user: ChatUser) {
            hideIndicator(for: user.id)
        }
        
        open func subscribeForPresence() {
            guard let data = data,
                  data.channel.isDirect,
                  let peer = data.channel.peer,
                  peer.state == .active
            else {
                presenceView.isHidden = true
                return
            }
            Components.presenceProvider.subscribe(userId: peer.id) { [weak self] userPresence in
                guard let self, let selfData = self.data, peer.id == selfData.channel.peer?.id
                else { return }
                self.presenceView.isHidden = userPresence.presence.state != .online
                let chatUser = ChatUser(user: userPresence.user)
                if chatUser !~= peer {
                    selfData.updateMemberWithUser(chatUser)
                    self.bind(selfData)
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

        /// Minimum inset between the avatar and the cell's top/bottom edges.
        public static var avatarVerticalPadding: CGFloat = 8
        /// Top inset of the message stack inside the cell.
        public static var messageStackTopPadding: CGFloat = 10
        /// Bottom inset of the message stack inside the cell.
        public static var messageStackBottomPadding: CGFloat = 6
        /// Vertical spacing between the subject and the message preview.
        public static var messageStackSpacing: CGFloat = 2
        /// Number of lines reserved for the message preview.
        public static var messagePreviewNumberOfLines: Int = 2

        /// Fixed row height for every channel cell.
        ///
        /// Computed so a full `messagePreviewNumberOfLines`-line preview always
        /// fits, and never shorter than the avatar. Because it is a constant the
        /// cell height no longer changes between 1-line and 2-line previews.
        ///
        /// - Parameter traitCollection: The trait collection whose
        ///   `preferredContentSizeCategory` the height should be sized for. Pass
        ///   the view's current trait collection so the fixed row height grows
        ///   with Large Text; `nil` uses the current environment. Sizes are
        ///   derived from `baseFont` (the un-scaled font), so the result tracks
        ///   the live category rather than the one frozen at launch.
        public static func cellHeight(compatibleWith traitCollection: UITraitCollection? = nil) -> CGFloat {
            let appearance = ChannelListViewController.ChannelCell.appearance
            let subjectHeight = appearance.subjectLabelAppearance.baseFont
                .asDynamic(compatibleWith: traitCollection).lineHeight
            let previewHeight = appearance.lastMessageLabelAppearance.baseFont
                .asDynamic(compatibleWith: traitCollection).lineHeight
                * CGFloat(messagePreviewNumberOfLines)
            let textHeight = messageStackTopPadding
                + subjectHeight
                + messageStackSpacing
                + previewHeight
                + messageStackBottomPadding
            let avatarHeight = avatarSize + avatarVerticalPadding * 2
            return ceil(max(textHeight, avatarHeight))
        }
    }
}
