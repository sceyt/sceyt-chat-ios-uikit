//
//  ChannelViewController+PinnedMessagesView.swift
//  SceytChatUIKit
//
//  Copyright © 2026 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController {

    /// The banner pinned under the navigation bar, showing one pinned message at a time.
    ///
    /// Layout note for anyone re-pinning this: the message list is **not** anchored to this
    /// view. `ChannelViewController` keeps its collection view pinned to the safe-area top and
    /// makes room with `collectionViewTopSpacing`, because in the default `.newestAtBottom`
    /// order the list is mirrored and content-space top/bottom are flipped.
    /// A plain `View`, not a `Control`: the tap and the two swipes are all gesture
    /// recognizers, so UIKit arbitrates between them. A `UIControl`'s own touch tracking
    /// competes with the swipe recognizers and swallows the gesture.
    open class PinnedMessagesView: View {

        public enum Action {
            /// About to advance to the next pinned message. Sent while the banner is still
            /// on the outgoing pin, so a handler can act on the one being left behind.
            case next
            /// About to go back to the previous one, likewise sent before the banner moves.
            case previous
            /// Jump the message list to the pin currently on screen.
            case jump
            /// Open the full pinned-messages list.
            case showList
        }

        /// Which way a page travels, which is what decides the side the incoming pin
        /// slides in from.
        public enum PagingDirection {
            /// Toward newer pins — the incoming pin arrives from below.
            case forward
            /// Toward older pins — the incoming pin arrives from above.
            case backward
        }

        open var onAction: ((Action) -> Void)?

        /// The pins to page through, in timeline order.
        open var items: [PinnedMessage] = [] {
            didSet {
                // A page still in flight would leave its snapshot stranded over the new pin.
                finishPaging()
                // Hold the banner on the pin the user was looking at. Pinning or unpinning
                // rewrites the whole array, and a bare clamp would slide the banner onto a
                // different message underneath them — which matters far more now that
                // tapping walks the pins one by one.
                let previousTid = oldValue.indices.contains(selectedIndex)
                    ? oldValue[selectedIndex].messageTid
                    : nil
                if let previousTid,
                   let index = items.firstIndex(where: { $0.messageTid == previousTid }) {
                    selectedIndex = index
                } else if selectedIndex >= items.count {
                    selectedIndex = max(0, items.count - 1)
                }
                // Unpinned messages leave their thumbnails behind otherwise, and the cache
                // outlives every pin in a long-lived channel.
                let liveTids = Set(items.map(\.messageTid))
                thumbnailCache = thumbnailCache.filter { liveTids.contains($0.key) }
                reload()
            }
        }

        /// Which pin is on screen. Wraps at both ends.
        open private(set) var selectedIndex: Int = 0

        open var selectedItem: PinnedMessage? {
            items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
        }

        /// One segment per pin. Past three pins the bar shows only a window of them —
        /// otherwise a channel with 50 pins would render 50 hairlines — and scrolls that
        /// window to keep the pin on screen highlighted inside it.
        open lazy var segmentIndicatorView = SegmentIndicatorView()
            .withoutAutoresizingMask

        /// The window the pins move past: static, and clipping, so a page never spills over
        /// the indicator or the pin button.
        open lazy var contentView = UIView()
            .withoutAutoresizingMask

        /// Everything that changes from pin to pin, in one view so a page can slide the
        /// thumbnail and the text together instead of animating them separately.
        open lazy var pageView = UIView()
            .withoutAutoresizingMask

        open lazy var imageView = UIImageView()
            .withoutAutoresizingMask
            .contentMode(.scaleAspectFill)

        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentCompressionResistancePriorityH(.required)

        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var pinButton = UIButton()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)

        open lazy var separatorView = UIView()
            .withoutAutoresizingMask

        open lazy var titleMessageVStack = UIStackView(
            column: [titleLabel, messageLabel],
            spacing: 2,
            distribution: .fillProportionally)
            .withoutAutoresizingMask

        /// Thumbnails already resolved, keyed by `messageTid`. Paging back to a pin then
        /// paints it straight away instead of going through the queue again, which is what
        /// would otherwise make the slot pop in a step late on every second pass.
        /// Only final ones are kept — see `isThumbnailFinal(for:)`.
        private var thumbnailCache: [Int64: UIImage] = [:]

        private var imageViewWidthConstraint: NSLayoutConstraint?
        /// Relaxed to zero once the bar scrolls — see `updateSegmentIndicatorInsets()`.
        private var segmentIndicatorTopConstraint: NSLayoutConstraint?
        private var segmentIndicatorBottomConstraint: NSLayoutConstraint?
        /// Collapsed along with the thumbnail's width, so a text-only pin has no gap left
        /// over where the image would have been.
        private var titleMessageVStackLeadingConstraint: NSLayoutConstraint?

        /// The outgoing pin, held over the window while it slides away.
        private weak var transitionSnapshot: UIView?

        open override func setup() {
            super.setup()

            titleLabel.text = L10n.Channel.PinnedMessages.title
            titleLabel.lineBreakMode = .byTruncatingTail
            messageLabel.lineBreakMode = .byTruncatingTail
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = Layouts.thumbnailCornerRadius
            contentView.clipsToBounds = true

            let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
            addGestureRecognizer(tap)
            pinButton.addTarget(self, action: #selector(onPinButton), for: .touchUpInside)

            // Dragging the banner walks the pins: up for the next, down for the previous,
            // matching the list itself, which runs oldest -> newest downward.
            //
            // A pan rather than a `UISwipeGestureRecognizer`: the banner is only ~52pt tall
            // and a swipe recognizer's distance threshold is most of that, so short drags
            // inside it are simply never recognized.
            let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan))
            addGestureRecognizer(pan)
            // The tap must lose to a drag, or a slightly-vertical tap jumps the list
            // instead of paging the banner.
            tap.require(toFail: pan)

            isAccessibilityElement = false
            accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.pinnedMessagesView
            titleLabel.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.pinnedMessagesTitle
            messageLabel.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.pinnedMessagesPreview
            pinButton.accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.pinnedMessagesButton
        }

        open override func setupLayout() {
            super.setupLayout()

            addSubview(segmentIndicatorView)
            addSubview(contentView)
            addSubview(pinButton)
            addSubview(separatorView)
            contentView.addSubview(pageView)
            pageView.addSubview(imageView)
            pageView.addSubview(titleMessageVStack)

            segmentIndicatorView.pin(to: self, anchors: [.leading(Layouts.horizontalPadding)])
            segmentIndicatorView.resize(anchors: [.width(Layouts.indicatorWidth)])
            segmentIndicatorTopConstraint = segmentIndicatorView.topAnchor
                .pin(to: topAnchor, constant: Layouts.verticalPadding)
            segmentIndicatorBottomConstraint = segmentIndicatorView.bottomAnchor
                .pin(to: bottomAnchor, constant: -Layouts.verticalPadding)

            contentView.leadingAnchor.pin(to: segmentIndicatorView.trailingAnchor, constant: Layouts.contentSpacing)
            contentView.trailingAnchor.pin(to: pinButton.leadingAnchor, constant: -Layouts.horizontalPadding)
            contentView.pin(to: self, anchors: [.top(Layouts.verticalPadding), .bottom(-Layouts.verticalPadding)])

            pageView.pin(to: contentView)

            imageView.pin(to: pageView, anchors: [.leading])
            imageView.centerYAnchor.pin(to: pageView.centerYAnchor)
            imageView.resize(anchors: [.height(Layouts.thumbnailSize)])
            imageViewWidthConstraint = imageView.resize(anchors: [.width(Layouts.thumbnailSize)]).first

            titleMessageVStackLeadingConstraint = titleMessageVStack.leadingAnchor.pin(to: imageView.trailingAnchor, constant: Layouts.contentSpacing)
            titleMessageVStack.centerYAnchor.pin(to: pageView.centerYAnchor)
            titleMessageVStack.trailingAnchor.pin(lessThanOrEqualTo: pageView.trailingAnchor)

            pinButton.pin(to: self, anchors: [.trailing(-Layouts.horizontalPadding)])
            pinButton.centerYAnchor.pin(to: centerYAnchor)
            pinButton.resize(anchors: [.width(Layouts.pinButtonSize), .height(Layouts.pinButtonSize)])

            separatorView.pin(to: self, anchors: [.leading, .trailing, .bottom])
            separatorView.resize(anchors: [.height(1)])
        }

        open override func setupAppearance() {
            super.setupAppearance()

            backgroundColor = appearance.backgroundColor
            separatorView.backgroundColor = appearance.separatorColor
            titleLabel.font = appearance.titleLabelAppearance.font
            titleLabel.textColor = appearance.titleLabelAppearance.foregroundColor
            messageLabel.font = appearance.messageLabelAppearance.font
            messageLabel.textColor = appearance.messageLabelAppearance.foregroundColor
            pinButton.setImage(appearance.pinIcon, for: .normal)
            pinButton.tintColor = appearance.pinIconTintColor
            segmentIndicatorView.activeColor = appearance.indicatorActiveColor
            segmentIndicatorView.inactiveColor = appearance.indicatorInactiveColor
            reload()
        }

        // MARK: - Paging

        open func select(index: Int, animated: Bool = false) {
            guard !items.isEmpty else { return }
            // Wrap, so a swipe never dead-ends at either edge.
            let wrapped = ((index % items.count) + items.count) % items.count
            guard wrapped != selectedIndex else { return }
            // Take the shorter way round the ring. A pin picked straight from the full list
            // then animates as the single step it is, rather than unwinding all the way back
            // through the ones in between.
            let forwardSteps = (wrapped - selectedIndex + items.count) % items.count
            let direction: PagingDirection = forwardSteps <= items.count / 2 ? .forward : .backward
            selectedIndex = wrapped

            guard animated else {
                reload()
                return
            }
            animatePaging(direction: direction) { [weak self] in
                self?.reload(animated: true)
            }
        }

        open func selectNext(animated: Bool = false) {
            select(index: selectedIndex + 1, animated: animated)
        }

        open func selectPrevious(animated: Bool = false) {
            select(index: selectedIndex - 1, animated: animated)
        }

        /// Cross-slides `pageView` over a snapshot of the pin it is replacing, so a page
        /// reads as the pins moving past a window rather than the preview being retyped
        /// in place.
        open func animatePaging(direction: PagingDirection, changes: () -> Void) {
            // Collapse anything still in flight first, so a flurry of swipes pages once per
            // swipe instead of stacking snapshots on top of each other.
            finishPaging()

            guard !UIAccessibility.isReduceMotionEnabled,
                  window != nil,
                  contentView.bounds.height > 0,
                  let snapshot = pageView.snapshotView(afterScreenUpdates: false)
            else {
                // Reduce Motion, or nothing on screen to snapshot: the swap still has to
                // happen, just without the slide.
                changes()
                return
            }

            // The snapshot belongs to `contentView`, not `pageView` — a child would travel
            // with the transform instead of staying behind to slide the other way.
            snapshot.frame = pageView.frame
            snapshot.isUserInteractionEnabled = false
            contentView.addSubview(snapshot)
            transitionSnapshot = snapshot

            changes()
            contentView.layoutIfNeeded()

            let distance = contentView.bounds.height
            let offset: CGFloat
            switch direction {
            case .forward: offset = distance
            case .backward: offset = -distance
            }

            // The incoming pin starts on the side the outgoing one is heading away from, so
            // the pair reads as one strip moving past the window.
            pageView.transform = CGAffineTransform(translationX: 0, y: offset)
            pageView.alpha = 0

            UIView.animate(
                withDuration: Layouts.pagingAnimationDuration,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut],
                animations: { [self] in
                    pageView.transform = .identity
                    pageView.alpha = 1
                    snapshot.transform = CGAffineTransform(translationX: 0, y: -offset)
                    snapshot.alpha = 0
                },
                completion: { [weak self] _ in
                    // A swipe that arrived mid-animation has already replaced this snapshot;
                    // its completion must not tear down the page that superseded it.
                    guard self?.transitionSnapshot === snapshot else { return }
                    self?.finishPaging()
                }
            )
        }

        /// Drops the outgoing snapshot and returns the content to rest. Safe at any point,
        /// including when no page is running.
        open func finishPaging() {
            transitionSnapshot?.removeFromSuperview()
            transitionSnapshot = nil
            pageView.layer.removeAllAnimations()
            pageView.transform = .identity
            pageView.alpha = 1
        }

        open func reload(animated: Bool = false) {
            updateSegmentIndicatorInsets()
            guard let item = selectedItem else {
                messageLabel.attributedText = nil
                apply(thumbnail: nil)
                segmentIndicatorView.update(count: 0, selected: 0)
                accessibilityValue = "0/0"
                return
            }

            messageLabel.attributedText = appearance.pinnedMessageBodyFormatter.format(
                .init(
                    message: item.previewMessage,
                    deletedStateText: appearance.deletedStateText,
                    bodyLabelAppearance: appearance.messageLabelAppearance,
                    mentionLabelAppearance: appearance.mentionLabelAppearance,
                    deletedLabelAppearance: appearance.messageLabelAppearance,
                    attachmentNameFormatter: appearance.attachmentNameFormatter,
                    attachmentDurationFormatter: appearance.attachmentDurationFormatter,
                    mentionUserNameFormatter: appearance.mentionUserNameFormatter
                )
            )

            // The slot is held open while the thumbnail resolves, so a media pin's text does
            // not start at the indicator for a frame and then shift right when the image
            // lands. It collapses again if nothing resolves.
            let cached = thumbnailCache[item.messageTid]
            apply(thumbnail: cached, reservingSlot: cached != nil || expectsThumbnail(for: item))
            loadThumbnail(for: item)

            segmentIndicatorView.update(count: items.count, selected: selectedIndex, animated: animated)

            // Published so a UI test can tell "the banner is showing pin 1 of 3" from
            // "only one pin ever landed" — the two look identical from the preview alone.
            accessibilityValue = "\(selectedIndex + 1)/\(items.count)"
        }

        /// How tall the indicator is allowed to be. While every pin has its own segment the
        /// bar is inset like the rest of the banner's content; once there are more pins than
        /// that and the bar starts scrolling, it runs the banner's full height instead, so
        /// the window is as tall as it can be and the half segment has room to read as one.
        open func updateSegmentIndicatorInsets() {
            let inset = items.count > Layouts.maxEqualIndicatorSegments ? 0 : Layouts.verticalPadding
            guard segmentIndicatorTopConstraint?.constant != inset else { return }
            segmentIndicatorTopConstraint?.constant = inset
            segmentIndicatorBottomConstraint?.constant = -inset
        }

        /// Paints the thumbnail, and sizes the slot it sits in. The gap after the image goes
        /// with the slot, so the text of a pin with no thumbnail sits one spacing from the
        /// indicator rather than two.
        ///
        /// `reservingSlot` keeps the space (and the gap) while a thumbnail is still being
        /// resolved, which is the only thing that separates "this pin has no image" from
        /// "its image has not arrived yet".
        open func apply(thumbnail: UIImage?, reservingSlot: Bool = false) {
            let showsSlot = thumbnail != nil || reservingSlot
            imageView.image = thumbnail
            imageView.isHidden = thumbnail == nil
            imageViewWidthConstraint?.constant = showsSlot ? Layouts.thumbnailSize : 0
            titleMessageVStackLeadingConstraint?.constant = showsSlot ? Layouts.contentSpacing : 0
        }

        /// Whether this pin is the kind that has a thumbnail at all — a photo, a video, or a
        /// previewable document. Answered from the pin row alone, so it costs nothing on the
        /// layout pass that has to decide whether to hold the slot open.
        open func expectsThumbnail(for item: PinnedMessage) -> Bool {
            guard let attachment = item.attachment else { return false }
            switch MessageLayoutModel.AttachmentLayout.AttachmentType(rawValue: attachment.type) {
            case .image, .video:
                return true
            case .file:
                let fileName = attachment.name
                    ?? ((attachment.url ?? attachment.filePath) as NSString?)?.lastPathComponent
                return AttachmentFileKind.kind(ofFileNamed: fileName).isPreviewable
            default:
                return false
            }
        }

        /// Resolves the pin's thumbnail away from the main thread and paints it if that pin
        /// is still the one on screen.
        ///
        /// Off the main thread because a video's poster frame is extracted from the file and
        /// re-encoded on a cache miss — orders of magnitude too much work for a layout pass,
        /// and the banner is built during the channel's first frames.
        open func loadThumbnail(for item: PinnedMessage) {
            let tid = item.messageTid
            guard item.attachment != nil, thumbnailCache[tid] == nil else { return }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let image = self.thumbnail(for: item)
                let isFinal = self.isThumbnailFinal(for: item)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    // A blurred thumbHash is deliberately not kept: it is what the pin shows
                    // until its media lands, and caching it would freeze the blur in place
                    // for as long as the pin exists.
                    if let image, isFinal {
                        self.thumbnailCache[tid] = image
                    }
                    guard self.selectedItem?.messageTid == tid else { return }
                    // Nothing resolved — a video with no metadata and nothing downloaded —
                    // so the slot `reload` held open closes rather than leaving an empty box.
                    self.apply(thumbnail: image)
                }
            }
        }

        /// The pinned message's thumbnail: a photo, a video's poster frame, or the preview of
        /// an image/video sent as a file. `nil` for everything else, including voice — which
        /// carries its length in the preview text instead.
        ///
        /// Resolved in the same order as `MessageLayoutModel.AttachmentLayout.loadThumbnail`,
        /// so the banner shows exactly what the message's own bubble does: the sharp on-disk
        /// thumbnail (generated from the local file, poster frame included), then the
        /// downloaded `video_thumb` poster, then the blurred thumbHash the sender ships in
        /// metadata.
        ///
        /// Called off the main thread by `loadThumbnail(for:)`; it touches no view state.
        open func thumbnail(for item: PinnedMessage) -> UIImage? {
            guard let attachment = item.previewMessage.attachments?.first else { return nil }
            switch MessageLayoutModel.AttachmentLayout.AttachmentType(rawValue: attachment.type) {
            case .image, .video:
                if let path = fileProvider.thumbnailFile(
                    for: attachment,
                    preferred: MessageLayoutModel.defaults.imageAttachmentSize
                ), let image = UIImage(contentsOfFile: path) {
                    return image
                }
                if let path = fileProvider.cachedVideoThumbnailPath(attachment: attachment),
                   let image = UIImage(contentsOfFile: path) {
                    return image
                }
                guard let metadata = attachment.imageDecodedMetadata else { return nil }
                if let image = metadata.thumbnailImage { return image }
                // thumbHash is what senders ship today; base64 is the legacy encoding of the
                // same field.
                return Components.imageBuilder.image(thumbHash: metadata.thumbnail)
                    ?? Components.imageBuilder.image(from: metadata.thumbnail)
            case .file:
                return attachment.filePreviewImage
            default:
                return nil
            }
        }

        /// Whether the thumbnail just resolved for `item` is as sharp as it will get: the
        /// media itself is on disk, or its poster frame is cached. While it is not, the
        /// banner is showing the blurred thumbHash, and re-resolving on the next reload is
        /// what lets the pin sharpen once the download lands.
        open func isThumbnailFinal(for item: PinnedMessage) -> Bool {
            guard let attachment = item.previewMessage.attachments?.first else { return true }
            return fileProvider.filePath(attachment: attachment) != nil
                || fileProvider.cachedVideoThumbnailPath(attachment: attachment) != nil
        }

        // MARK: - Actions

        @objc
        open func onTap() { onAction?(.jump) }

        @objc
        open func onPinButton() { onAction?(.showList) }

        @objc
        open func onPan(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .ended else { return }
            let translation = gesture.translation(in: self).y
            let velocity = gesture.velocity(in: self).y

            // Either a deliberate short drag or a quick flick counts.
            let travelled = abs(translation) >= Layouts.pagingTranslationThreshold
            let flicked = abs(velocity) >= Layouts.pagingVelocityThreshold
            guard travelled || flicked else { return }

            // Prefer the flick's direction when the drag itself barely moved.
            let goesUp = travelled ? translation < 0 : velocity < 0
            // Announce the page *before* running it, so the handler still sees the pin the
            // user was looking at. A swipe then reads exactly like a tap: the list travels
            // to the pin on screen, and the banner is left on the one that follows.
            if goesUp {
                onAction?(.next)
                selectNext(animated: true)
            } else {
                onAction?(.previous)
                selectPrevious(animated: true)
            }
        }

        public enum Layouts {
            public static var height: CGFloat = 52
            public static var horizontalPadding: CGFloat = 12
            public static var verticalPadding: CGFloat = 8
            public static var indicatorWidth: CGFloat = 2
            /// Gap around the paging window: indicator -> thumbnail -> text.
            public static var contentSpacing: CGFloat = 8
            public static var thumbnailSize: CGFloat = 32
            public static var thumbnailCornerRadius: CGFloat = 8
            public static var pinButtonSize: CGFloat = 24
            /// Vertical drag, in points, that pages the banner.
            public static var pagingTranslationThreshold: CGFloat = 12
            /// Flick speed, in points per second, that pages it regardless of distance.
            public static var pagingVelocityThreshold: CGFloat = 300
            /// Up to this many pins the bar splits its whole height into equal segments.
            public static var maxEqualIndicatorSegments: Int = 3
            /// Past that, the bar scrolls and shows this many segments alongside the end
            /// padding. The half segment is the cue that there are more pins beyond the
            /// window.
            public static var visibleIndicatorSegments: CGFloat = 3.5
            /// Gap between two segments.
            public static var indicatorSegmentSpacing: CGFloat = 2
            /// How long a page takes. Long enough to read as movement, short enough that a
            /// series of taps walking the pins does not feel gated by it.
            public static var pagingAnimationDuration: TimeInterval = 0.25
        }
    }
}

// MARK: - Segment indicator

extension ChannelViewController.PinnedMessagesView {

    /// The vertical bar on the leading edge: one segment per pin, the active one highlighted.
    ///
    /// Up to `Layouts.maxEqualIndicatorSegments` pins every segment is drawn, sharing the
    /// bar's height equally. Past that the bar becomes a window scrolled over the segments:
    /// `Layouts.visibleIndicatorSegments` of them are on screen at a time — the trailing half
    /// segment being the cue that the list runs on — and the window is offset to keep the
    /// selected segment centred.
    ///
    /// The scrolling bar runs the banner's full height (`PinnedMessagesView` drops its inset
    /// for it) and keeps the padding as a `contentInset` instead, the way a scroll view does:
    /// resting at either end the first or last segment sits `Layouts.verticalPadding` inside
    /// the bar, while the middle of the list scrolls straight through that space.
    open class SegmentIndicatorView: View {

        open var activeColor: UIColor = .accent { didSet { setNeedsLayout() } }
        open var inactiveColor: UIColor = .border { didSet { setNeedsLayout() } }

        private var count: Int = 0
        private var selected: Int = 0
        /// Only the segments inside the window are given a layer, keyed by the pin's index so
        /// one that stays on screen across a page keeps its layer — and with it the
        /// highlight's crossfade and the scroll's frame animation.
        private var segmentLayers: [Int: CALayer] = [:]

        open override func setup() {
            super.setup()
            // The window clips: a segment scrolled half out of it is drawn cut, which is what
            // makes the half segment read as "there is more below".
            layer.masksToBounds = true
        }

        open func update(count: Int, selected: Int, animated: Bool = false) {
            self.count = count
            self.selected = selected
            layoutSegments(animated: animated)
        }

        open override func layoutSubviews() {
            super.layoutSubviews()
            layoutSegments()
        }

        /// Space kept at both ends of a scrolling bar, exactly like a scroll view's
        /// `contentInset`. Zero while every segment is on screen, since the bar itself is
        /// inset then.
        private var contentInset: CGFloat {
            count <= Layouts.maxEqualIndicatorSegments ? 0 : Layouts.verticalPadding
        }

        /// Height of one segment plus the gap after it — the distance from one segment's top
        /// to the next one's, which is what the window is scrolled in terms of.
        private func pitch(spacing: CGFloat) -> CGFloat {
            guard count > Layouts.maxEqualIndicatorSegments else {
                // Every segment and the gaps between them fill the bar exactly.
                return (bounds.height + spacing) / CGFloat(max(count, 1))
            }
            // What is left of the bar once one inset is taken off holds
            // `visibleIndicatorSegments` of them, so resting at either end the window reads
            // as exactly that many segments next to the padding. Sized this way a segment
            // also stays about as tall as it was at three pins, so crossing into the
            // scrolling bar does not resize the whole track.
            return (bounds.height - contentInset + spacing) / Layouts.visibleIndicatorSegments
        }

        private func layoutSegments(animated: Bool = false) {
            guard count > 0, bounds.height > 0, bounds.width > 0 else {
                removeLayers(keeping: [])
                return
            }

            let spacing: CGFloat = count > 1 ? Layouts.indicatorSegmentSpacing : 0
            let pitch = pitch(spacing: spacing)
            let segmentHeight = pitch - spacing
            guard segmentHeight > 0 else { return }

            let inset = contentInset
            let contentHeight = pitch * CGFloat(count) - spacing
            // Centre the selected segment, then clamp: with everything visible, and at either
            // end of a longer list, there is nothing to scroll to and the offset lands on a
            // bound — which is where the inset shows up as the padding above the first
            // segment and below the last.
            let centred = pitch * CGFloat(selected) + segmentHeight / 2 - bounds.height / 2
            let minOffset = -inset
            let maxOffset = max(contentHeight - bounds.height + inset, minOffset)
            let offset = min(max(centred, minOffset), maxOffset)

            let first = max(Int(floor(offset / pitch)), 0)
            let last = min(Int(floor((offset + bounds.height - 1) / pitch)), count - 1)
            guard first <= last else { return }

            // Paging asks for the highlight to crossfade and the window to slide; a plain
            // layout pass must not animate at all, or every relayout smears the bar.
            CATransaction.begin()
            CATransaction.setDisableActions(!animated)
            CATransaction.setAnimationDuration(Layouts.pagingAnimationDuration)

            removeLayers(keeping: Set(first ... last))
            for index in first ... last {
                let layer = segmentLayers[index] ?? makeLayer(at: index)
                layer.frame = CGRect(
                    x: 0,
                    y: pitch * CGFloat(index) - offset,
                    width: bounds.width,
                    height: segmentHeight
                )
                layer.backgroundColor = (index == selected ? activeColor : inactiveColor).cgColor
            }

            CATransaction.commit()
        }

        private func makeLayer(at index: Int) -> CALayer {
            let layer = CALayer()
            layer.cornerRadius = Layouts.indicatorWidth / 2
            // A segment scrolling into the window starts where it belongs rather than
            // sliding in from the layer's default zero frame.
            layer.frame = CGRect(x: 0, y: bounds.height, width: bounds.width, height: 0)
            self.layer.addSublayer(layer)
            segmentLayers[index] = layer
            return layer
        }

        private func removeLayers(keeping indices: Set<Int>) {
            for (index, layer) in segmentLayers where !indices.contains(index) {
                layer.removeFromSuperlayer()
                segmentLayers[index] = nil
            }
        }
    }
}
