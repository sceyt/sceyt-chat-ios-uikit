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

    open class ReplyView: Control, MessageCellMeasurable {

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
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 4

            borderView.clipsToBounds = true
            borderView.layer.cornerRadius = 2
        }
       
        open override func setupLayout() {
            super.setupLayout()
            addSubview(stackViewH)
            stackViewH.addArrangedSubview(borderView)
            stackViewH.addArrangedSubview(stackViewV)
            stackViewV.addArrangedSubview(nameLabel)
            stackViewH2.addArrangedSubview(messageLabel)
            stackViewV.addArrangedSubview(stackViewH2)
            stackViewH.setCustomSpacing(8, after: borderView)
            stackViewH.pin(to: self, anchors: [.leading(0), .trailing(-8), .top(6), .bottom(-6)])
            borderView.resize(anchors: [.width(2)])
            borderView.heightAnchor.pin(to: self.heightAnchor)
            stackViewV.heightAnchor.pin(to: stackViewH.heightAnchor)
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
                stackViewH2.spacing = 4.0
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
                messageLabel.numberOfLines = 2
                stackViewV.distribution = .fill
                guard let attachment = data.attachment
                else { return }
                imageView.image = attachment.thumbnail

                var willLoadLinkImage = false
                if attachment.type == .link {
                    willLoadLinkImage = true
                    imageView.image = Images.replyLinkPlaceholder
                    if let urlString = attachment.attachment.url,
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

                guard imageView.image != nil || willLoadLinkImage else { return }
                messageLabel.numberOfLines = 1
                stackViewV.distribution = .fillEqually
                stackViewH.insertArrangedSubview(imageView, at: 1)
                stackViewH.setCustomSpacing(8, after: imageView)
                imageView.addConstraints([
                    imageView.heightAnchor.pin(constant: Measure.imageSize.height),
                    imageView.widthAnchor.pin(constant: Measure.imageSize.width)
                ])
                setProgressHandler()
            }
        }
        
        open func setProgressHandler() {
            guard let data = data,
                  let attachment = data.attachment,
                  attachment.type != .link  // link images are managed via LinkMetadataProvider, not fileProvider
            else { return }
            let message = data.message
            let chatAttachment = attachment.attachment

            // Refresh the preview whenever the thumbnail finishes loading — at bind,
            // after `update(attachment:)`, or once the parent's file downloads. The
            // reply layout is built from the parent message and is NOT rebuilt when the
            // parent's attachment downloads, so without this hook the preview can stay
            // stuck on the blurred placeholder even after the image is on disk.
            attachment.onLoadThumbnail = { [weak self, weak data] image in
                guard let self, let data, self.data === data, let image
                else { return }
                self.imageView.image = image
            }

            // Observe an in-flight transfer (e.g. the replied-to message is also on
            // screen and downloading the same attachment under the same key).
            fileProvider
                .progress(
                    message: message,
                    attachment: chatAttachment,
                    objectIdKey: chatAttachment.description + "reply"
                ) { _ in
                    
                } completion: { done in
                    if done.error == nil {
                        fileProvider.removeProgressObserver(message: done.message, attachment: done.attachment)
                    }
                    // Reloads the thumbnail from the now-downloaded file; the
                    // onLoadThumbnail hook above pushes it into the image view.
                    data.attachment?.update(attachment: done.attachment)
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
                ) { resolvedMessage, error in
                    guard error == nil else { return }
                    let resolved = resolvedMessage?.attachments?.first(where: { $0.id == chatAttachment.id }) ?? chatAttachment
                    data.attachment?.update(attachment: resolved)
                }
            }
        }
        
        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            guard let data = model.replyLayout else { return .zero }
            
            var space = 0.0
            var iconSize = data.icon == nil ? .zero : Measure.iconSize
            if iconSize != .zero {
                iconSize.width += 2
            }
            var thumbnailSize = data.attachment?.thumbnail == nil ? .zero : Measure.imageSize
            if thumbnailSize != .zero {
                thumbnailSize.width += 8
            }
            
            space = iconSize.width + thumbnailSize.width
            if space == 0 {
                space = 10
            }
            var config = TextSizeMeasure.Config(maximumNumberOfLines: 1, lastFragmentUsedRect: false)
            config.font = appearance.replyMessageAppearance.titleLabelAppearance.font
            config.restrictingWidth = MessageLayoutModel.defaults.messageWidth - thumbnailSize.width
            let user = SceytChatUIKit.shared.formatters.userNameFormatter.format(data.user)
            let nameLabelSize = TextSizeMeasure.calculateSize(of: user, config: config).textSize
            
            config.font = appearance.replyMessageAppearance.subtitleLabelAppearance.font
            config.restrictingWidth = MessageLayoutModel.defaults.messageWidth - space
            config.maximumNumberOfLines = data.attachment == nil ? 2 : 1
            let messageLabelSize = TextSizeMeasure.calculateSize(of: data.attributedBody, config: config).textSize
            
            return CGSize(width: thumbnailSize.width + max(nameLabelSize.width, iconSize.width + messageLabelSize.width) + 8,
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
    }
}

