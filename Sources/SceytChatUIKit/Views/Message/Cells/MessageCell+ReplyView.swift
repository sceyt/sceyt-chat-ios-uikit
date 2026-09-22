//
//  MessageCell+ReplyView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import SceytChat

extension MessageCell {

    open class ReplyView: Control, MessageCellMeasurable, AttachmentSharpThumbnailObserver {

        open lazy var nameLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var messageLabel = UILabel()
            .withoutAutoresizingMask

        open lazy var imageView = UIImageView()
            .contentMode(.scaleAspectFill)
            .withoutAutoresizingMask
        
        open lazy var iconView = UIImageView()
            .withoutAutoresizingMask

        open lazy var borderView = UIView()
            .withoutAutoresizingMask

        open lazy var stackViewV = UIStackView()
            .withoutAutoresizingMask

        open lazy var stackViewH = UIStackView()
            .withoutAutoresizingMask
        
        open lazy var stackViewH2 = UIStackView()
            .withoutAutoresizingMask
        
        public lazy var appearance = Components.messageCell.appearance {
            didSet {
                setupAppearance()
            }
        }

        open override func setup() {
            super.setup()
            stackViewV.isUserInteractionEnabled = false
            stackViewH.isUserInteractionEnabled = false
            stackViewH2.isUserInteractionEnabled = false
            borderView.isUserInteractionEnabled = false

            // Surface as a single tappable button for VoiceOver and UI tests (a
            // bare UIControl is not an accessibility element by default).
            isAccessibilityElement = true
            accessibilityTraits = .button
            accessibilityIdentifier = SceytChatUIKit.AccessibilityIdentifiers.Channel.Cell.replyView
            
            stackViewV.distribution = .fill
            stackViewV.alignment = .leading
            stackViewV.axis = .vertical

            stackViewH.distribution = .fill
            stackViewH.alignment = .center
            stackViewH.axis = .horizontal
            
            stackViewH2.distribution = .fill
            stackViewH2.alignment = .leading
            stackViewH2.axis = .horizontal
            stackViewH2.spacing = 2
            
            messageLabel.lineBreakMode = .byTruncatingTail

            nameLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 4

            borderView.clipsToBounds = true
            borderView.layer.cornerRadius = 2

            // Weak registration for the view's whole lifetime — the relay prunes dead
            // observers itself. See `attachmentSharpThumbnailDidLoad` for why the reply
            // preview needs this backstop at all.
            AttachmentSharpThumbnailRelay.default.add(self)
        }

        /// Backstop delivery of the blurry→sharp swap (see `AttachmentSharpThumbnailRelay`).
        ///
        /// A reply preview is the one thumbnail consumer that gets no help from the
        /// database: `LazyMessagesObserver` refreshes a message row for
        /// `attachments.status`/`attachments.filePath`, which reaches the message that
        /// OWNS the image — never the message quoting it. So the parent's bubble heals
        /// through a full rebind while this view is left to heal itself, off a single
        /// overwritable `onLoadThumbnail` slot and a progress observer that any rebind,
        /// duplicate layout instance or already-in-flight transfer can leave it out of.
        /// The relay is keyed by attachment identity and per-view, so none of that can
        /// steal the image.
        open func attachmentSharpThumbnailDidLoad(_ attachment: ChatMessage.Attachment, image: UIImage) {
            guard let layout = data?.attachment,
                  layout.type != .link,
                  layout.attachment == attachment
            else { return }
            // One attachment is consumed at several design sizes, each with its own
            // size-keyed thumbnail file. Anything at least as big as this 32pt slot is an
            // upgrade over the thumbHash blur; a smaller sibling result is not.
            let displayScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
            let requiredPxMaxSide = max(Measure.imageSize.width, Measure.imageSize.height) * displayScale
            let imagePxMaxSide = max(image.size.width, image.size.height) * image.scale
            guard imagePxMaxSide >= requiredPxMaxSide else { return }
            if !(layout.isThumbnailLoadedFromFile && layout.thumbnail === image) {
                layout.setFileBackedThumbnail(image)
            }
            insertImageViewIfNeeded()
            imageView.image = image
        }
       
        open override func setupLayout() {
            super.setupLayout()

            addSubview(borderView)
            addSubview(stackViewH)
            stackViewH.addArrangedSubview(stackViewV)
            stackViewV.addArrangedSubview(nameLabel)
            stackViewH2.addArrangedSubview(messageLabel)
            stackViewV.addArrangedSubview(stackViewH2)
            borderView.pin(to: self, anchors: [.leading(0), .top(0), .bottom(0)])
            borderView.resize(anchors: [.width(Measure.borderWidth)])
            stackViewH.pin(to: self, anchors: [.leading(Measure.borderWidth + Measure.borderSpacing), .trailing(-Measure.trailingInset), .top(6), .bottom(-6)])
        }

        open override func setupAppearance() {
            super.setupAppearance()
            isHidden = true

            nameLabel.font = appearance.replyMessageAppearance.titleLabelAppearance.font
            nameLabel.textColor = appearance.replyMessageAppearance.titleLabelAppearance.foregroundColor

            messageLabel.font = appearance.replyMessageAppearance.subtitleLabelAppearance.font
            messageLabel.textColor = appearance.replyMessageAppearance.subtitleLabelAppearance.foregroundColor
            
            borderView.backgroundColor = appearance.replyMessageAppearance.borderColor
        }

        open var data: MessageLayoutModel.ReplyLayout? {
            didSet {
                stackViewH.removeArrangedSubview(imageView)
                stackViewH2.removeArrangedSubview(iconView)
                imageView.removeFromSuperview()
                iconView.removeFromSuperview()
                imageView.image = nil
                NSLayoutConstraint.deactivate(imageView.constraints)
                
                guard let data = data else {
                    isHidden = true
                    return
                }
                isHidden = false
                backgroundColor = data.byMe ? appearance.outgoingReplyBackgroundColor : appearance.incomingReplyBackgroundColor
                layer.cornerRadius = Layouts.cornerRadius
                layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
                layer.masksToBounds = true
                nameLabel.text = appearance.replyMessageAppearance.senderNameFormatter.format(data.user)
                messageLabel.attributedText = data.attributedBody
                stackViewH2.spacing = Measure.iconSpacing
                if let image = data.icon {
                    stackViewH2.insertArrangedSubview(iconView, at: 0)
                    iconView.image = image.withTintColor(.accent, renderingMode: .alwaysTemplate)
                    iconView.tintColor = .accent
                    iconView.addConstraints([
                        iconView.heightAnchor.pin(constant: Measure.iconSize.height),
                        iconView.widthAnchor.pin(constant: Measure.iconSize.width)
                    ])
                } else {
                    iconView.image = nil
                }
                messageLabel.numberOfLines = Measure.maximumNumberOfLines
                stackViewV.distribution = .fill
                guard let attachment = data.attachment
                else { return }
                imageView.image = attachment.thumbnail

                var willLoadLinkImage = false
                if attachment.type == .link {
                    willLoadLinkImage = true
                    imageView.image = Images.replyLinkPlaceholder
                    if attachment.attachment.imageDecodedMetadata?.hideLinkDetails == true {
                        // The sender disabled the preview for this link, so its site image
                        // must not resurface here — keep the generic link icon and skip the
                        // metadata lookup/fetch below entirely.
                        imageView.image = appearance.linkPreviewAppearance.placeholderIcon ?? Images.replyLinkPlaceholder
                    } else if let urlString = attachment.attachment.url,
                       let linkUrl = URL(string: urlString) {
                        // Use the same image LinkPreviewView shows
                        if let metadata = LinkMetadataProvider.default.metadata(for: linkUrl) {
                            let cachedImage = metadata.thumbnail ?? metadata.image
                            if let cachedImage {
                                imageView.image = cachedImage
                            }
                        } else {
                            // Not cached yet — fetch async and update once ready
                            willLoadLinkImage = true
                            let capturedData = data
                            LinkMetadataProvider.default.fetch(url: linkUrl) { [weak self] result in
                                guard case .success(let metadata) = result else { return }
                                let image = metadata.thumbnail ?? metadata.image
                                DispatchQueue.main.async {
                                    guard let self else { return }
                                    guard self.data === capturedData else {
                                        logger.debug("[ReplyView] async link fetch — data changed after scroll, skipping")
                                        return
                                    }
                                    if let image {
                                        self.imageView.image = image
                                    }
                                }
                            }
                        }
                    }
                }

                guard imageView.image != nil || willLoadLinkImage else {
                    // The thumbnail of a just-rebuilt AttachmentLayout lands via
                    // DispatchQueue.main.async and can arrive AFTER this bind (e.g. a
                    // reaction update recreates ReplyLayout mid-flight). Wire the
                    // observers anyway — onLoadThumbnail inserts the image view once
                    // the thumbnail arrives; bailing without wiring loses the image
                    // until the next rebind.
                    setProgressHandler()
                    return
                }
                insertImageViewIfNeeded()
                setProgressHandler()
            }
        }
        
        /// Puts the thumbnail image view into the horizontal stack. Idempotent — also
        /// called from `onLoadThumbnail` when the thumbnail arrives after bind (the
        /// deferred-insert path in `data.didSet`).
        ///
        /// Deliberately does NOT touch `messageLabel.numberOfLines` or the stack
        /// distribution: the thumbnail lands asynchronously (always after `measure`,
        /// see `AttachmentLayout.loadThumbnail`), so clamping the label here would
        /// shrink it below the size the cell was measured for and truncate text the
        /// bubble has room for.
        open func insertImageViewIfNeeded() {
            guard imageView.superview == nil else { return }
            stackViewH.insertArrangedSubview(imageView, at: 0)
            stackViewH.setCustomSpacing(Measure.thumbnailSpacing, after: imageView)
            imageView.addConstraints([
                imageView.heightAnchor.pin(constant: Measure.imageSize.height),
                imageView.widthAnchor.pin(constant: Measure.imageSize.width)
            ])
        }

        open func setProgressHandler() {
            guard let data = data,
                  let attachment = data.attachment,
                  attachment.type != .link  // link images are managed via LinkMetadataProvider, not fileProvider
            else { return }
            let message = data.message
            let chatAttachment = attachment.attachment
            // Captured by value, not recomputed from `self` in the completion: when the
            // view is gone by the time the transfer ends, deriving the key there yields
            // "", and `removeProgressObserver` reads an empty key as "drop the whole
            // bucket" — silently unsubscribing every OTHER view on this attachment,
            // including the parent bubble's live progress ring. A captured key always
            // removes exactly this view's own registration.
            let observerKey = AttachmentTransfer.observerKey(for: self, prefix: "reply")

            // Refresh the preview whenever the thumbnail finishes loading — at bind,
            // after `update(attachment:)`, or once the parent's file downloads. The
            // reply layout is built from the parent message and is NOT rebuilt when the
            // parent's attachment downloads, so without this hook the preview can stay
            // stuck on the blurred placeholder even after the image is on disk.
            attachment.onLoadThumbnail = { [weak self, weak data] image in
                guard let self, let data, self.data === data, let image
                else { return }
                self.insertImageViewIfNeeded()
                self.imageView.image = image
            }

            // Observe an in-flight transfer (e.g. the replied-to message is also on
            // screen and downloading the same attachment under the same key).
            fileProvider
                .progress(
                    message: message,
                    attachment: chatAttachment,
                    objectIdKey: observerKey
                ) { _ in

                } completion: { [weak data] done in
                    if done.error == nil {
                        fileProvider.removeProgressObserver(
                            message: done.message,
                            attachment: done.attachment,
                            objectIdKey: observerKey
                        )
                    }
                    // Reloads the thumbnail from the now-downloaded file; the
                    // onLoadThumbnail hook above pushes it into the image view.
                    data?.attachment?.update(attachment: done.attachment)
                }

            // The reply view used to only *observe* progress and never started the
            // download, so a reply whose parent attachment wasn't already being
            // fetched by another visible cell stayed blurred forever. Start it here
            // (a no-op if already in flight or done). The completion also fires on the
            // already-downloaded fast path, refreshing a stale placeholder from disk.
            DispatchQueue.global().async {
                fileProvider.downloadMessageAttachmentsIfNeeded(
                    message: message,
                    attachments: [chatAttachment]
                ) { [weak data] resolvedMessage, error in
                    guard error == nil else { return }
                    let resolved = resolvedMessage?.attachments?.first(where: { $0.id == chatAttachment.id }) ?? chatAttachment
                    data?.attachment?.update(attachment: resolved)
                }
            }
        }
        
        #if DEBUG
        /// Publishes which thumbnail this preview is actually painting, so a UI test can
        /// tell the blurred `thumbHash` placeholder from the sharp file-backed image.
        ///
        /// Computed on read rather than stamped on write: the thumbnail arrives through
        /// several asynchronous paths (bind, `onLoadThumbnail`, a transfer completing),
        /// and a getter cannot go stale the way a cached value assigned at only some of
        /// those sites would — which is exactly the failure mode under test here.
        open override var accessibilityValue: String? {
            get {
                guard let attachment = data?.attachment, attachment.type != .link
                else { return nil }
                guard imageView.image != nil, imageView.superview != nil
                else { return SceytChatUIKit.AccessibilityIdentifiers.Channel.Cell.thumbnailNone }
                return attachment.isThumbnailLoadedFromFile
                    ? SceytChatUIKit.AccessibilityIdentifiers.Channel.Cell.thumbnailSharp
                    : SceytChatUIKit.AccessibilityIdentifiers.Channel.Cell.thumbnailBlurred
            }
            set { super.accessibilityValue = newValue }
        }
        #endif

        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            guard let data = model.replyLayout else { return .zero }

            // Reserve the thumbnail on `attachment != nil`, NOT on `thumbnail != nil`:
            // the thumbnail is published on the main queue by
            // `AttachmentLayout.loadThumbnail`, i.e. always after the layout model
            // (and therefore this measure) has run, so it is nil here every time.
            // Keying off it left the 32pt image + 8pt spacing unaccounted for and cut
            // ~40pt off the text the bubble was sized to show.
            var iconSize = data.icon == nil ? .zero : Measure.iconSize
            if iconSize != .zero {
                iconSize.width += Measure.iconSpacing
            }
            var thumbnailSize = data.attachment == nil ? .zero : Measure.imageSize
            if thumbnailSize != .zero {
                thumbnailSize.width += Measure.thumbnailSpacing
            }

            // Width the labels really get inside the view: the reply view is capped at
            // `Anchors.width` and spends `Measure.chromeWidth` on the trailing inset,
            // the border and the border spacing, plus the thumbnail column.
            let availableWidth = Anchors.width - Measure.chromeWidth - thumbnailSize.width

            var config = TextSizeMeasure.Config(maximumNumberOfLines: 1, lastFragmentUsedRect: false)
            config.font = appearance.replyMessageAppearance.titleLabelAppearance.font
            config.restrictingWidth = availableWidth

            let user = appearance.replyMessageAppearance.senderNameFormatter.format(data.user)
            let nameLabelSize = TextSizeMeasure.calculateSize(of: user, config: config).textSize

            config.font = nil
            let body = NSMutableAttributedString(attributedString: data.attributedBody)
            body.enumerateAttribute(.font, in: NSRange(location: 0, length: body.length)) { value, range, _ in
                if value == nil {
                    body.addAttribute(.font, value: appearance.replyMessageAppearance.subtitleLabelAppearance.font, range: range)
                }
            }
            // The icon shares the row with the message label only.
            config.restrictingWidth = availableWidth - iconSize.width
            config.maximumNumberOfLines = 1
            let singleLineHeight = TextSizeMeasure.calculateSize(of: body, config: config).textSize.height
            config.maximumNumberOfLines = Measure.maximumNumberOfLines
            var messageLabelSize = TextSizeMeasure.calculateSize(of: body, config: config).textSize
            if messageLabelSize.height > singleLineHeight {
                messageLabelSize.width = config.restrictingWidth
            }

            return CGSize(width: Measure.chromeWidth + thumbnailSize.width + max(nameLabelSize.width, iconSize.width + messageLabelSize.width),
                          height: max(thumbnailSize.height, nameLabelSize.height + max(iconSize.height, messageLabelSize.height)) + 16)
        }
    }
}

public extension MessageCell.ReplyView {
    enum Anchors {
        public static var top = CGFloat(8)
        public static var leading = CGFloat(12)
        public static var trailing = CGFloat(-12)
        public static var width: CGFloat { Components.messageLayoutModel.defaults.messageWidth - leading + trailing }
    }
    
    enum Measure {
        public static var iconSize = CGSize(width: 16, height: 16)
        public static var imageSize = CGSize(width: 32, height: 32)
        /// Lines the message preview may occupy, with or without a thumbnail.
        public static var maximumNumberOfLines: Int = 2
        /// Gap between the attachment-type icon and the message preview.
        public static var iconSpacing: CGFloat = 4
        /// Gap between the thumbnail and the text column.
        public static var thumbnailSpacing: CGFloat = 8
        public static var borderWidth: CGFloat = 2
        /// Gap between the accent border and the content that follows it.
        public static var borderSpacing: CGFloat = 8
        public static var trailingInset: CGFloat = 8
        /// Width the view spends on everything but the thumbnail and the labels.
        /// Keep in sync with `setupLayout()`.
        public static var chromeWidth: CGFloat { trailingInset + borderWidth + borderSpacing }
    }
}

