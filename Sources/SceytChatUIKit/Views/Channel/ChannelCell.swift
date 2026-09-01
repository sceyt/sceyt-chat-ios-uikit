//
//  ChannelCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import SceytChat
import UIKit

private typealias CellAID = SceytChatUIKit.AccessibilityIdentifiers.ChannelList.Cell

extension ChannelListViewController {
    open class ChannelCell: TableViewCell {
        
        // MARK: - Stack hierarchy
        //
        // contentStackView (H)
        // ├─ avatarContainer                  (avatar + presence / retention overlays)
        // └─ rightStackView (V)
        //    ├─ topRowStackView (H)           [ subjectStackView ──spacer── dateStackView ]
        //    │  ├─ subjectStackView (H)        [ subjectLabel  muteView ]
        //    │  └─ dateStackView (H)           [ ticksView  dateLabel ]
        //    └─ bottomRowStackView (H)        [ messageLabel ──spacer── badgeStackView ]
        //       └─ badgeStackView (H)          [ atView  unreadCount pinView ]

        /// The view that slides under the finger, hosting everything the row
        /// draws. `contentView` itself is never transformed: UIKit re-frames it
        /// on every layout pass, which would reset or double-apply the
        /// translation.
        open lazy var swipeContentView = UIView().withoutAutoresizingMask

        /// The superview the row's content is laid out against.
        ///
        /// Defaults to `swipeContentView`, so the content travels with the
        /// swipe. Override to return `contentView` to opt a subclass's layout
        /// out of sliding — the actions then reveal underneath a static row.
        open var contentContainerView: UIView { swipeContentView }

        /// Leading (Read/Unread, Pin/Unpin) actions, parked just outside the
        /// cell's leading edge.
        open lazy var leadingActionsView: ChannelSwipeActionsView = {
            let view = Components.channelSwipeActionsView.init().withoutAutoresizingMask
            view.side = .leading
            return view
        }()

        /// Trailing (Delete/Leave, Mute/Unmute) actions, parked just outside the
        /// cell's trailing edge.
        open lazy var trailingActionsView: ChannelSwipeActionsView = {
            let view = Components.channelSwipeActionsView.init().withoutAutoresizingMask
            view.side = .trailing
            return view
        }()

        open lazy var swipePanGestureRecognizer = UIPanGestureRecognizer(
            target: self, action: #selector(handleSwipePan(_:)))

        /// Set to `false` to disable the in-cell swipe for this cell. The
        /// channel list sets it from `usesNativeSwipeActions`.
        open var swipeActionsEnabled = true

        /// Whether an over-drag performs the outermost action, the way
        /// `UISwipeActionsConfiguration.performsFirstActionWithFullSwipe` does.
        /// The channel list sets this from its own property of the same name.
        open var performsFirstActionWithFullSwipe = false

        /// Fraction of the row's width past which a full swipe fires, when
        /// `performsFirstActionWithFullSwipe` is on.
        open var fullSwipeThresholdFraction: CGFloat = 0.6

        /// Signed, **leading-relative** content offset: negative always reveals
        /// the trailing actions, in both LTR and RTL. `0` is closed.
        ///
        /// Keeping the offset direction-independent confines RTL handling to the
        /// two places that deal in physical pixels — `handleSwipePan(_:)` and
        /// `setSwipeOffset(_:animated:velocity:completion:)` — instead of
        /// scattering sign flips through the file.
        public private(set) var swipeOffset: CGFloat = 0

        public enum SwipeEvent {
            case began
            /// Live offset while dragging.
            case changed(CGFloat)
            /// Offset the row settled at; `0` means closed.
            case settled(CGFloat)
            case action(ChannelSwipeActionsConfiguration.Actions)
        }

        /// Set by the channel list, which owns the open-swipe state keyed by
        /// channel id so it survives reorders and cell reuse.
        open var onSwipeEvent: ((SwipeEvent) -> Void)?

        /// The action lists the current buttons were built from, so the frequent
        /// re-binds (presence, typing, reconfigure) don't rebuild the views.
        private var boundSwipeActions: (leading: [ChannelSwipeActionsConfiguration.Actions],
                                        trailing: [ChannelSwipeActionsConfiguration.Actions])?

        /// Offset at the start of the current pan.
        private var panStartOffset: CGFloat = 0

        /// Whether the current drag is past the full-swipe threshold. Latched so
        /// the haptic fires once per crossing rather than on every touch move,
        /// and re-armed when the drag falls back below it.
        private var isFullSwipeActivated = false

        /// Feedback for crossing the full-swipe threshold. `.medium` matches the
        /// message list's swipe-to-reply, the other pan-threshold gesture in the
        /// SDK.
        open lazy var fullSwipeFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

        private var isRightToLeft: Bool {
            effectiveUserInterfaceLayoutDirection == .rightToLeft
        }

        /// Shorthand for the swipe styling statics.
        private typealias SwipeAppearance = ChannelSwipeActionsConfiguration.Appearance

        open lazy var contentStackView = UIStackView(arrangedSubviews: [avatarContainer, rightStackView])
            .withoutAutoresizingMask

        /// Non-clipping host for the avatar so the presence / retention badges
        /// can extend beyond the (clipped) avatar image.
        open lazy var avatarContainer = UIView()
            .withoutAutoresizingMask

        open lazy var rightStackView = UIStackView(arrangedSubviews: [topRowStackView, bottomRowStackView])
            .withoutAutoresizingMask

        /// Top row: subject (left, expands) + date (right, fixed size).
        open lazy var topRowStackView = UIStackView(arrangedSubviews: [subjectStackView, topRowSpacerView, dateStackView])
            .withoutAutoresizingMask

        /// Bottom row: message preview (left, expands) + badges (right).
        open lazy var bottomRowStackView = UIStackView(arrangedSubviews: [messageLabel, bottomRowSpacerView, badgeStackView])
            .withoutAutoresizingMask

        open lazy var subjectStackView = UIStackView(arrangedSubviews: [subjectLabel, muteView])
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)
            .contentCompressionResistancePriorityH(.defaultLow)

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

        /// Flexible spacer between subject/mute and the fixed trailing date row.
        open lazy var topRowSpacerView = UIView()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(UILayoutPriority(1))

        /// Flexible spacer between the message preview and the trailing badges.
        /// Shown only while the preview is hidden (no last message): without it
        /// the badge stack is the row's sole visible item, so `.fill` stretches
        /// it full-width and the aspect-fit pin icon renders centered instead of
        /// trailing. While the preview is visible the label itself absorbs the
        /// slack, so the spacer is hidden to keep the original 8pt badge gap.
        open lazy var bottomRowSpacerView = UIView()
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

        /// Size constraints for the mute icon, recomputed for the current Dynamic
        /// Type category so the icon scales alongside the subject label.
        private var muteWidthConstraint: NSLayoutConstraint?
        private var muteHeightConstraint: NSLayoutConstraint?

        override open func prepareForReuse() {
            super.prepareForReuse()
            clearEvents()
            subscriptions.removeAll(keepingCapacity: true)
            // A recycled cell must never arrive half-open showing another
            // channel's actions. The channel list restores the offset in
            // `cellForRowAt` for the row that is actually open.
            onSwipeEvent = nil
            boundSwipeActions = nil
            isFullSwipeActivated = false
            setSwipeOffset(0, animated: false)
        }
        
        override open func setup() {
            super.setup()
            backgroundView = UIView()

            swipePanGestureRecognizer.delegate = self
            addGestureRecognizer(swipePanGestureRecognizer)
            leadingActionsView.onAction = { [weak self] in self?.onSwipeEvent?(.action($0)) }
            trailingActionsView.onAction = { [weak self] in self?.onSwipeEvent?(.action($0)) }

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

            topRowStackView.distribution = .fill
            topRowStackView.spacing = Layouts.topRowSpacing
            updateTopRowAxis()

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
            badgeStackView.spacing = 4

            messageLabel.numberOfLines = Layouts.messagePreviewNumberOfLines
            muteView.image = appearance.mutedIcon

            // The unread badge must never be taller than it is wide: a single
            // digit stays a circle, longer counts (e.g. "99+") grow horizontally.
            unreadCount.keepsWidthAtLeastHeight = true

            // Re-scale the (UIFontMetrics-based) fonts live when the user changes
            // the Dynamic Type / Large Text setting, instead of only after an app
            // relaunch. The row height is recomputed for the new category in
            // ChannelListViewController.traitCollectionDidChange.
            [subjectLabel, messageLabel, dateLabel, unreadCount, atView]
                .forEach { $0.adjustsFontForContentSizeCategory = true }

            setupAccessibilityIdentifiers()
        }

        /// Assigns the stable `accessibilityIdentifier`s used both by assistive
        /// technologies and by the UI tests that drive this screen.
        ///
        /// The labels and badges are accessibility elements by default (they are
        /// `UILabel`s), so they are observable as soon as they carry text. The
        /// status icons are decorative `UIImageView`s that Auto Layout hides when
        /// inactive; promoting them to accessibility elements — with a label —
        /// makes their presence/absence observable and also lets VoiceOver
        /// announce the channel's muted / pinned / delivery state, which it does
        /// not today.
        open func setupAccessibilityIdentifiers() {
            avatarView.accessibilityIdentifier = CellAID.avatar
            subjectLabel.accessibilityIdentifier = CellAID.subject
            messageLabel.accessibilityIdentifier = CellAID.message
            dateLabel.accessibilityIdentifier = CellAID.date
            unreadCount.accessibilityIdentifier = CellAID.unreadBadge
            atView.accessibilityIdentifier = CellAID.mentionBadge

            // Plain literals rather than L10n keys: the localization table is
            // SwiftGen-generated, so adding entries belongs in a follow-up that
            // also regenerates L10n. These English fallbacks are still strictly
            // better than the (silent) status quo for VoiceOver.
            muteView.accessibilityIdentifier = CellAID.muteIcon
            muteView.isAccessibilityElement = true
            muteView.accessibilityLabel = "Muted"

            pinView.accessibilityIdentifier = CellAID.pinIcon
            pinView.isAccessibilityElement = true
            pinView.accessibilityLabel = "Pinned"

            // `ticksView.isAccessibilityElement` is driven in `bind(_:)` — it is
            // exposed only when an actual delivery-status icon is shown.
            ticksView.accessibilityIdentifier = CellAID.ticks
            ticksView.accessibilityLabel = "Message delivery status"
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

            // The swipe machinery lives inside `contentView`: the action
            // containers sit just outside its edges and are clipped away until
            // the row slides, so progressive reveal costs no layout pass.
            contentView.clipsToBounds = true
            contentView.addSubview(leadingActionsView)
            contentView.addSubview(trailingActionsView)
            contentView.addSubview(swipeContentView)

            swipeContentView.pin(to: contentView)

            leadingActionsView.pin(to: contentView, anchors: [.top(), .bottom()])
            leadingActionsView.trailingAnchor.pin(to: contentView.leadingAnchor)

            trailingActionsView.pin(to: contentView, anchors: [.top(), .bottom()])
            trailingActionsView.leadingAnchor.pin(to: contentView.trailingAnchor)

            contentContainerView.addSubview(contentStackView)
            // The separator has to slide with the content: its leading is pinned
            // to `rightStackView`, a descendant of `contentStackView`, and Auto
            // Layout ignores `transform`. Left in `contentView` it would stay put
            // while the content moved, drifting away from the avatar inset.
            contentContainerView.addSubview(separatorView)

            // Pin the content to the top so the subject row is fixed there. The
            // cell height is a constant sized for a full preview, and the avatar
            // is the tallest item, so a top inset of avatarVerticalPadding leaves
            // the avatar exactly where centering used to put it — while the
            // message preview now grows downward instead of shifting the subject.
            contentStackView.pin(to: contentContainerView, anchors: [
                .leading(Layouts.horizontalPadding),
                .top(Layouts.avatarVerticalPadding)
            ])
            contentStackView.trailingAnchor.pin(to: contentContainerView.trailingAnchor, constant: -Layouts.horizontalPadding)
            // Fixed bottom: the cell height is a constant, so the content fills the
            // vertical area exactly (8…56…8). With `.top` alignment the avatar fills
            // it and the subject stays pinned to the top.
            contentStackView.bottomAnchor.pin(to: contentContainerView.bottomAnchor, constant: -Layouts.avatarVerticalPadding)

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

            // The mute icon has no fixed size: it's driven by these constraints,
            // recomputed from the icon's intrinsic size scaled for the current
            // Dynamic Type category (see updateMuteViewSize), so it grows with the
            // subject label it sits next to.
            muteWidthConstraint = muteView.widthAnchor.pin(constant: 0)
            muteHeightConstraint = muteView.heightAnchor.pin(constant: 0)
            updatePinViewSize()
            updateTicksViewSize()
            updateMuteViewSize()

            atView.heightAnchor.pin(to: unreadCount.heightAnchor).isActive = true

            separatorView.pin(to: contentContainerView, anchors: [.bottom(), .trailing(-Layouts.horizontalPadding)])
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
            pinView.image = appearance.pinIcon
            if data == nil {
                pinView.isHidden = true
            } else {
                pinView.isHidden = data.channel.pinnedAt == nil
                updatePinViewSize()
            }
            muteView.isHidden = true
        }

        override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)

            if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
                retentionBadgeView.layer.borderColor = DefaultColors.background.resolvedColor(with: traitCollection).cgColor
            }

            // Large Text changed: grow/shrink the tick and pin alongside their
            // neighboring labels/badges, and reflow the top row (date moves to
            // its own line once the text reaches the accessibility sizes).
            if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
                updateTicksViewSize()
                updatePinViewSize()
                updateMuteViewSize()
                updateTopRowAxis()
                updateSwipeActionWidths()
            }
        }

        /// Reflows the top row for the current Dynamic Type category.
        ///
        /// At normal sizes the subject and the date share one horizontal line,
        /// with the date pinned to the trailing edge. At accessibility sizes the
        /// time gets squeezed against that edge to the point of being unreadable,
        /// so the row switches to a vertical axis and the date drops onto its own
        /// full-width line under the subject (left-aligned).
        ///
        /// The flexible trailing spacer only does its job in the horizontal
        /// layout (it pushes the date right); stacked vertically it would just
        /// add a gap between the two lines, so it is hidden.
        ///
        /// The fixed cell height accounts for that extra line under the same
        /// accessibility condition — see `Layouts.cellHeight`.
        /// Re-measures the swipe action buttons for the current Dynamic Type
        /// category. The channel list closes any open swipe before its own
        /// reload, so there is no open offset to preserve here.
        open func updateSwipeActionWidths() {
            leadingActionsView.recomputeWidths()
            trailingActionsView.recomputeWidths()
            if swipeOffset != 0 { clampSwipeOffsetToFullReveal() }
        }

        open func updateTopRowAxis() {
            let category = UIApplication.shared.preferredContentSizeCategory
            if Layouts.prefersVerticalTopRow(for: category) {
                topRowStackView.axis = .vertical
                topRowStackView.alignment = .leading
                topRowSpacerView.isHidden = true
            } else {
                topRowStackView.axis = .horizontal
                topRowStackView.alignment = .center
                topRowSpacerView.isHidden = false
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

        /// Scales the mute icon with Dynamic Type.
        ///
        /// The base size is the icon's own intrinsic size, scaled by the same
        /// factor the subject label uses (its text style), so the icon keeps its
        /// design size at the default Large Text setting and grows proportionally
        /// from there — staying visually aligned with the subject next to it.
        open func updateMuteViewSize() {
            guard let size = muteView.image?.size, size != .zero else { return }
            let style = UIFont.preferredTextStyle(for: appearance.subjectLabelAppearance.baseFont.pointSize)
            let metrics = UIFontMetrics(forTextStyle: style)
            muteWidthConstraint?.constant = metrics.scaledValue(for: size.width, compatibleWith: traitCollection)
            muteHeightConstraint?.constant = metrics.scaledValue(for: size.height, compatibleWith: traitCollection)
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
            updateContentAlignment()
        }

        /// Vertically centers the subject row against the avatar when nothing
        /// sits below it — no message preview and no badges — instead of leaving
        /// it pinned to the top with empty space underneath. As soon as there is
        /// a preview (or a badge), the content snaps back to `.top` so a
        /// multi-line preview grows downward without shifting the subject (see
        /// the alignment rationale in `setup`).
        ///
        /// Called from `bind(_:)` after the badge visibility is resolved, and
        /// from `update(messageText:)` so transient typing / recording
        /// indicators re-show the (otherwise hidden) label and re-evaluate.
        open func updateContentAlignment() {
            let hasMessage = !(messageLabel.attributedText?.string.isEmpty ?? true)
            messageLabel.isHidden = !hasMessage
            // Keep the badges (pin/unread/@) pinned to the trailing edge when
            // the preview is gone — see `bottomRowSpacerView`.
            bottomRowSpacerView.isHidden = hasMessage

            let bottomRowEmpty = messageLabel.isHidden
                && unreadCount.isHidden
                && atView.isHidden
                && pinView.isHidden
            contentStackView.alignment = bottomRowEmpty ? .center : .top
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
            accessibilityIdentifier = CellAID.identifier(for: data.channel.id)
            subjectLabel.text = data.formattedSubject
            update(messageText: data.attributedView)
            dateLabel.text = data.formattedDate
            pinView.isHidden = data.channel.pinnedAt == nil
            updatePinViewSize()
            backgroundColor = data.channel.pinnedAt == nil ? .clear : appearance.backgroundColor
            backgroundView?.backgroundColor = appearance.backgroundColor
            
            ticksView.image = deliveryStatusImage(message: data.lastMessage)
            ticksView.isHidden = !data.shouldShowDeliveryTick
            // `shouldShowDeliveryTick` is true for any last message, but the tick
            // image is only set for *outgoing* ones. When there is no icon, keep
            // the tick out of the accessibility tree entirely (silent for
            // VoiceOver, and not matchable by its identifier in UI tests).
            let hasDeliveryTick = ticksView.image != nil
            ticksView.isAccessibilityElement = hasDeliveryTick
            ticksView.accessibilityIdentifier = hasDeliveryTick ? CellAID.ticks : nil
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

            // Center the subject row when the channel has no preview/badges
            // below it; otherwise keep it pinned to the top. Done here, after
            // the badge visibility above is resolved, so the decision sees the
            // final state.
            updateContentAlignment()

            configureSwipeActions(for: data.channel)

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
            // The swipe pan has to be able to begin while the table's own pan is
            // already tracking — a scroll view starts on any direction, so it
            // would otherwise always win. Once the swipe begins, the channel list
            // disables table scrolling for its duration, so the two never
            // actually run together.
            true
        }

        override open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === swipePanGestureRecognizer else {
                return super.gestureRecognizerShouldBegin(gestureRecognizer)
            }
            guard swipeActionsEnabled, data != nil else { return false }

            // Horizontal-dominant only, so a vertical drag scrolls the list
            // untouched. Velocity rather than translation: at `.began` the
            // translation is still ~zero, which makes a translation-based test
            // jittery.
            let velocity = swipePanGestureRecognizer.velocity(in: self)
            guard abs(velocity.x) > abs(velocity.y) else { return false }

            let towardTrailing = isRightToLeft ? velocity.x > 0 : velocity.x < 0

            // Don't fight the navigation controller's interactive pop, which is a
            // leading-edge horizontal pan. Only relevant when the channel list is
            // pushed onto a non-empty stack — in the demo app it is the root, so
            // no UI test can catch this.
            if !towardTrailing, canBePopped {
                let location = swipePanGestureRecognizer.location(in: self)
                let distanceFromLeadingEdge = isRightToLeft
                    ? bounds.maxX - location.x
                    : location.x - bounds.minX
                if distanceFromLeadingEdge < Layouts.interactivePopEdgeWidth { return false }
            }

            // A closed row only opens toward a side that actually has actions;
            // an open row can always be dragged closed.
            if swipeOffset == 0 {
                return towardTrailing
                    ? trailingActionsView.fullRevealWidth > 0
                    : leadingActionsView.fullRevealWidth > 0
            }
            return true
        }

        /// Whether this cell's view controller sits on a navigation stack that
        /// can be popped by the interactive back gesture.
        private var canBePopped: Bool {
            var responder: UIResponder? = self
            while let current = responder {
                if let viewController = current as? UIViewController {
                    return (viewController.navigationController?.viewControllers.count ?? 0) > 1
                }
                responder = current.next
            }
            return false
        }

        // MARK: - Swipe actions

        /// Rebuilds the action buttons when — and only when — the channel's state
        /// changed which actions it offers.
        ///
        /// This is what keeps a persistently open swipe honest: a channel that
        /// receives a message while its row is open flips Unread to Read, so the
        /// button is re-labelled in place rather than performing a stale action.
        /// Because a title change also changes the button's width, the open
        /// offset is re-clamped to the new full reveal.
        open func configureSwipeActions(for channel: ChatChannel) {
            let config = Components.channelSwipeActionsConfiguration
            let leading = config.leadingActions(chatChannel: channel)
            let trailing = config.trailingActions(chatChannel: channel)
            guard boundSwipeActions?.leading != leading
                    || boundSwipeActions?.trailing != trailing
            else { return }
            boundSwipeActions = (leading, trailing)
            leadingActionsView.configure(items: config.leadingActionItems(chatChannel: channel))
            trailingActionsView.configure(items: config.trailingActionItems(chatChannel: channel))
            setupSwipeAccessibilityCustomActions(for: channel)
            if swipeOffset != 0 { clampSwipeOffsetToFullReveal() }
        }

        /// Donates the swipe actions to VoiceOver, Switch Control and Full
        /// Keyboard Access, all of which `UISwipeActionsConfiguration` reached
        /// automatically and a custom implementation does not.
        open func setupSwipeAccessibilityCustomActions(for channel: ChatChannel) {
            let config = Components.channelSwipeActionsConfiguration
            let items = config.leadingActionItems(chatChannel: channel)
                + config.trailingActionItems(chatChannel: channel)
            accessibilityCustomActions = items.compactMap { item in
                guard let name = item.appearance.title, !name.isEmpty else { return nil }
                return UIAccessibilityCustomAction(name: name) { [weak self] _ in
                    self?.onSwipeEvent?(.action(item.action))
                    return true
                }
            }
        }

        /// The two-finger-Z escape gesture closes the row, as it did with native
        /// swipe actions.
        override open func accessibilityPerformEscape() -> Bool {
            guard swipeOffset != 0 else { return false }
            onSwipeEvent?(.settled(0))
            setSwipeOffset(0, animated: true)
            return true
        }

        /// Re-clamps the offset after the action set — and therefore the reveal
        /// width — changed underneath an open row.
        open func clampSwipeOffsetToFullReveal() {
            let clamped: CGFloat
            if swipeOffset < 0 {
                clamped = -min(-swipeOffset, trailingActionsView.fullRevealWidth)
            } else {
                clamped = min(swipeOffset, leadingActionsView.fullRevealWidth)
            }
            guard clamped != swipeOffset else { return }
            setSwipeOffset(clamped, animated: false)
        }

        /// Moves the row to `offset`, sliding the content and both action
        /// containers by the same physical distance.
        open func setSwipeOffset(_ offset: CGFloat,
                                 animated: Bool,
                                 velocity: CGFloat = 0,
                                 completion: (() -> Void)? = nil) {
            let distance = max(1, abs(offset - swipeOffset))
            swipeOffset = offset

            let apply = { [self] in
                let dx = isRightToLeft ? -offset : offset
                let translation = CGAffineTransform(translationX: dx, y: 0)
                swipeContentView.transform = translation
                leadingActionsView.transform = translation
                trailingActionsView.transform = translation
                trailingActionsView.setOverDrag(-offset - trailingActionsView.fullRevealWidth)
                leadingActionsView.setOverDrag(offset - leadingActionsView.fullRevealWidth)
                // On top of that shared slide, each button lags by what is still
                // to come on its side, so the actions widen from zero together
                // rather than arriving one at a time.
                leadingActionsView.setRevealedWidth(max(0, offset), mirrored: isRightToLeft)
                trailingActionsView.setRevealedWidth(max(0, -offset), mirrored: isRightToLeft)
                // Over-drag mutates a width constraint, so it has to be laid out
                // inside the animation block to be animated with the transform.
                layoutIfNeeded()
            }

            // While the row is open its actions are the primary target; the
            // selection highlight underneath would otherwise paint through.
            selectionStyle = offset == 0 ? .default : .none
            leadingActionsView.accessibilityElementsHidden = offset <= 0
            trailingActionsView.accessibilityElementsHidden = offset >= 0

            guard animated, !UIAccessibility.isReduceMotionEnabled else {
                UIView.performWithoutAnimation { apply() }
                completion?()
                return
            }
            UIView.animate(withDuration: SwipeAppearance.settleAnimationDuration,
                           delay: 0,
                           usingSpringWithDamping: SwipeAppearance.settleSpringDamping,
                           initialSpringVelocity: min(3, abs(velocity) / distance),
                           // Without `.allowUserInteraction` a fast
                           // open-then-tap-the-button sequence drops the tap.
                           options: [.allowUserInteraction, .beginFromCurrentState],
                           animations: apply,
                           completion: { _ in completion?() })
        }

        @objc open func handleSwipePan(_ sender: UIPanGestureRecognizer) {
            let fullTrailing = trailingActionsView.fullRevealWidth
            let fullLeading = leadingActionsView.fullRevealWidth

            switch sender.state {
            case .began:
                panStartOffset = swipeOffset
                isFullSwipeActivated = false
                if performsFirstActionWithFullSwipe {
                    // Warm the Taptic Engine so the bump lands with the crossing
                    // rather than a beat after it.
                    fullSwipeFeedbackGenerator.prepare()
                }
                onSwipeEvent?(.began)

            case .changed:
                let physicalDx = sender.translation(in: self).x
                let dx = isRightToLeft ? -physicalDx : physicalDx
                let offset = ChannelCell.clampedSwipeOffset(
                    panStartOffset + dx,
                    fullLeading: fullLeading,
                    fullTrailing: fullTrailing,
                    rubberBandFactor: effectiveRubberBandFactor)
                setSwipeOffset(offset, animated: false)
                onSwipeEvent?(.changed(offset))
                updateFullSwipeActivation(for: offset)

            case .ended, .cancelled, .failed:
                let physicalVx = sender.velocity(in: self).x
                let vx = isRightToLeft ? -physicalVx : physicalVx

                isFullSwipeActivated = false

                if performsFirstActionWithFullSwipe,
                   let action = fullSwipeAction(for: swipeOffset) {
                    onSwipeEvent?(.settled(0))
                    setSwipeOffset(0, animated: true, velocity: vx) { [weak self] in
                        self?.onSwipeEvent?(.action(action))
                    }
                    return
                }

                let target = ChannelCell.settleTarget(
                    offset: swipeOffset,
                    velocity: vx,
                    fullLeading: fullLeading,
                    fullTrailing: fullTrailing,
                    openThreshold: SwipeAppearance.openThreshold)
                setSwipeOffset(target, animated: true, velocity: vx)
                onSwipeEvent?(.settled(target))

            default:
                break
            }
        }

        /// Tracks whether the drag is past the full-swipe threshold and reports
        /// each crossing.
        ///
        /// `UISwipeActionsConfiguration` gives a haptic *while* dragging, the
        /// moment a full swipe becomes armed — the bump is what tells you that
        /// releasing now performs the action rather than just opening the row. So
        /// this is driven from `.changed`, not from the release.
        func updateFullSwipeActivation(for offset: CGFloat) {
            guard performsFirstActionWithFullSwipe else {
                isFullSwipeActivated = false
                return
            }
            let activated = fullSwipeAction(for: offset) != nil
            guard activated != isFullSwipeActivated else { return }
            isFullSwipeActivated = activated
            // Only the crossing into the armed state is worth feeling; dragging
            // back out again is silent, as it is natively.
            if activated { fullSwipeThresholdDidCross() }
        }

        /// Called when a drag crosses the full-swipe threshold, so the user feels
        /// that releasing now performs the row's first action.
        ///
        /// Override to change the feedback, or to silence it.
        open func fullSwipeThresholdDidCross() {
            fullSwipeFeedbackGenerator.impactOccurred()
            // Re-arm for a possible second crossing within the same drag.
            fullSwipeFeedbackGenerator.prepare()
        }

        /// Resistance applied to drag past the full reveal width.
        ///
        /// Normally the reveal is a dead end, and the rubber band says so. With
        /// `performsFirstActionWithFullSwipe` on it is not: dragging further is
        /// the gesture that fires the action, so the row has to follow the finger
        /// or the threshold sits beyond the width of the screen and can never be
        /// reached.
        open var effectiveRubberBandFactor: CGFloat {
            performsFirstActionWithFullSwipe ? 1 : SwipeAppearance.rubberBandFactor
        }

        /// The outermost action, when the row was dragged far enough for a full
        /// swipe to fire it.
        open func fullSwipeAction(for offset: CGFloat) -> ChannelSwipeActionsConfiguration.Actions? {
            let threshold = bounds.width * fullSwipeThresholdFraction
            if offset < 0, -offset > threshold {
                // On the trailing side the outermost button is laid out last.
                return trailingActionsView.buttons.last?.item?.action
            }
            if offset > 0, offset > threshold {
                return leadingActionsView.buttons.first?.item?.action
            }
            return nil
        }

        // MARK: - Swipe geometry
        //
        // Pure functions so the drag maths can be unit-tested without a table.

        /// Clamps a raw drag offset, rubber-banding past the full reveal and
        /// hard-stopping at a side with no actions.
        public static func clampedSwipeOffset(_ offset: CGFloat,
                                              fullLeading: CGFloat,
                                              fullTrailing: CGFloat,
                                              rubberBandFactor: CGFloat) -> CGFloat {
            if offset < 0 {
                guard fullTrailing > 0 else { return 0 }
                return -rubberBanded(-offset, limit: fullTrailing, factor: rubberBandFactor)
            }
            if offset > 0 {
                guard fullLeading > 0 else { return 0 }
                return rubberBanded(offset, limit: fullLeading, factor: rubberBandFactor)
            }
            return 0
        }

        /// Where a released drag settles: fully open on the side it is already
        /// showing, or closed.
        public static func settleTarget(offset: CGFloat,
                                        velocity: CGFloat,
                                        fullLeading: CGFloat,
                                        fullTrailing: CGFloat,
                                        openThreshold: CGFloat) -> CGFloat {
            guard offset != 0 else { return 0 }
            // Project where the finger was heading, the way a scroll view does.
            // The projection decides open-versus-closed only; the *side* comes
            // from the current offset. Otherwise a hard flick back past zero
            // would fling the row open on the opposite side instead of closing it.
            let projected = offset + velocity * Layouts.swipeVelocityProjectionInterval
            if offset < 0 {
                guard fullTrailing > 0 else { return 0 }
                return -projected > fullTrailing * openThreshold ? -fullTrailing : 0
            }
            guard fullLeading > 0 else { return 0 }
            return projected > fullLeading * openThreshold ? fullLeading : 0
        }

        private static func rubberBanded(_ magnitude: CGFloat,
                                         limit: CGFloat,
                                         factor: CGFloat) -> CGFloat {
            magnitude <= limit ? magnitude : limit + (magnitude - limit) * factor
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

        /// Width of the leading strip reserved for the navigation controller's
        /// interactive pop gesture, where a leading swipe will not begin.
        public static var interactivePopEdgeWidth: CGFloat = 20

        /// How far ahead a released swipe's velocity is projected when deciding
        /// whether it settles open or closed. Matches `UIScrollView`'s feel.
        public static var swipeVelocityProjectionInterval: CGFloat = 0.15
        /// Top inset of the message stack inside the cell.
        public static var messageStackTopPadding: CGFloat = 10
        /// Bottom inset of the message stack inside the cell.
        public static var messageStackBottomPadding: CGFloat = 6
        /// Vertical spacing between the subject and the message preview.
        public static var messageStackSpacing: CGFloat = 2
        /// Spacing between the subject and the date in the top row. Horizontal
        /// at normal text sizes; at accessibility sizes the top row becomes
        /// vertical and this is the gap above the date's own line.
        public static var topRowSpacing: CGFloat = 8
        /// Number of lines reserved for the message preview.
        public static var messagePreviewNumberOfLines: Int = 2

        /// The Dynamic Type steps at which the top row switches from horizontal
        /// to vertical so the date moves onto its own line. Only the two largest
        /// accessibility sizes, where the time would otherwise be squeezed
        /// against the trailing edge to the point of being unreadable.
        ///
        /// Single source of truth for both `updateTopRowAxis` (the layout) and
        /// `cellHeight` (the reserved height) so the two can't drift apart — a
        /// mismatch would clip the date or the message preview.
        public static var verticalTopRowSizes: [UIContentSizeCategory] = [
            .accessibilityExtraExtraLarge,
            .accessibilityExtraExtraExtraLarge
        ]

        /// Whether the top row should stack vertically for the given category.
        public static func prefersVerticalTopRow(for category: UIContentSizeCategory) -> Bool {
            verticalTopRowSizes.contains(category)
        }

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
            let previewHeight = messagePreviewHeight(compatibleWith: traitCollection)
            var textHeight = messageStackTopPadding
                + subjectHeight
                + messageStackSpacing
                + previewHeight
                + messageStackBottomPadding
            // At the two largest Dynamic Type steps the top row stacks vertically
            // and the date moves onto its own line under the subject (see
            // updateTopRowAxis). Reserve that extra line + the top-row spacing so
            // the fixed height grows to fit it instead of clipping the date or
            // the message preview. The decision uses the same app-wide category
            // as updateTopRowAxis so the layout and the reserved height always
            // agree; the added line is scaled from the passed trait collection.
            let category = UIApplication.shared.preferredContentSizeCategory
            if prefersVerticalTopRow(for: category) {
                let dateHeight = appearance.dateLabelAppearance.baseFont
                    .asDynamic(compatibleWith: traitCollection).lineHeight
                textHeight += topRowSpacing + dateHeight
            }
            let avatarHeight = avatarSize + avatarVerticalPadding * 2
            return ceil(max(textHeight, avatarHeight))
        }

        public static func messagePreviewHeight(compatibleWith traitCollection: UITraitCollection? = nil) -> CGFloat {
            let appearance = ChannelListViewController.ChannelCell.appearance
            let font = appearance.lastMessageLabelAppearance.baseFont
                .asDynamic(compatibleWith: traitCollection)
            return ceil(font.lineHeight * CGFloat(messagePreviewNumberOfLines))
        }
    }
}
