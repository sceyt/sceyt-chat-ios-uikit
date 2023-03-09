//
//  IncomingMessageCell.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

open class IncomingMessageCell: MessageCell {
    
    open override var isHighlightedBubbleView: Bool {
        didSet {
            bubbleView.backgroundColor = isHighlightedBubbleView
            ? appearance.highlightedBubbleColor.in
            : appearance.bubbleColor.in
        }
    }

    open override func layoutConstraints(layout: MessageLayoutModel) -> [NSLayoutConstraint] {

        var layoutConstraint = [NSLayoutConstraint]()

        bubbleView.backgroundColor = appearance.bubbleColor.in
        infoView.dateLabel.textColor = appearance.infoViewDateTextColor

        infoView.tickView.isHidden = true
        let hasName = layout.contentOptions.contains(.name)
        var options = layout.contentOptions
        options.remove(.name)
        let showName = hasName && showSenderInfo
//        let isOnlyMedia = layout.contentOptions.contains(.image) && !layout.contentOptions.contains(.text) && !layout.hasReply
        let bubbleViewTopAnchor: NSLayoutYAxisAnchor
        let contentTopAnchor: NSLayoutYAxisAnchor
        
        if layout.isForwarded {
            let topAnchor = showSenderInfo ? nameLabel.bottomAnchor : unreadView.bottomAnchor
            layoutConstraint += [
                forwardView.topAnchor.pin(to: topAnchor, constant: 8),
                forwardView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                forwardView.trailingAnchor.pin(lessThanOrEqualTo: bubbleView.trailingAnchor, constant: -12),
                forwardView.widthAnchor.pin(lessThanOrEqualToConstant: Components.messageLayoutModel.defaults.messageWidth)
            ]
            bubbleViewTopAnchor = forwardView.bottomAnchor
            contentTopAnchor = forwardView.bottomAnchor
        } else if layout.hasReply {
            let topAnchor = showSenderInfo ? nameLabel.bottomAnchor : unreadView.bottomAnchor
            layoutConstraint += [
                replyView.topAnchor.pin(to: topAnchor, constant: 8),
                replyView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                replyView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                replyView.widthAnchor.pin(lessThanOrEqualToConstant: Components.messageLayoutModel.defaults.messageWidth)
            ]
            bubbleViewTopAnchor = replyView.bottomAnchor
            contentTopAnchor = replyView.bottomAnchor
        } else {
            bubbleViewTopAnchor = bubbleView.topAnchor
            contentTopAnchor = hasName ? nameLabel.bottomAnchor : bubbleViewTopAnchor
        }

        if hasName && showSenderInfo {
            layoutConstraint += [
                avatarView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: 12),
                avatarView.topAnchor.pin(to: unreadView.bottomAnchor),
                avatarView.widthAnchor.pin(constant: 36),
                avatarView.heightAnchor.pin(constant: 36),

                nameLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                nameLabel.topAnchor.pin(to: bubbleView.topAnchor, constant: 8),
                nameLabel.widthAnchor.pin(constant: layout.messageUserTitleSize.width),
//                nameLabel.heightAnchor.pin(constant: 18)
            ]
        } else if hasName && !showSenderInfo {
            layoutConstraint += [
                avatarView.leadingAnchor.pin(to: contentView.leadingAnchor, constant: 12),
                avatarView.topAnchor.pin(to: unreadView.bottomAnchor),
                avatarView.widthAnchor.pin(constant: 36),
                avatarView.heightAnchor.pin(constant: 36),

                nameLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                nameLabel.topAnchor.pin(to: bubbleViewTopAnchor),
                nameLabel.widthAnchor.pin(constant: 0),
                nameLabel.heightAnchor.pin(constant: 0)
            ]
        } else {
            layoutConstraint += [
                avatarView.leadingAnchor.pin(to: contentView.leadingAnchor),
                avatarView.topAnchor.pin(to: unreadView.bottomAnchor),
                avatarView.widthAnchor.pin(constant: 0),
                avatarView.heightAnchor.pin(constant: 0),

                nameLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                nameLabel.topAnchor.pin(to: bubbleViewTopAnchor),
                nameLabel.widthAnchor.pin(constant: 0),
                nameLabel.heightAnchor.pin(constant: 0)
            ]
        }
        
        if options == .text {
            layoutConstraint += [
                bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                bubbleView.trailingAnchor.pin(to: infoView.trailingAnchor, constant: 12),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),
                bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: (showName ? layout.messageUserTitleSize.width : 0) + 24),
                textView.topAnchor.pin(to: contentTopAnchor, constant: layout.isForwarded ? 2 : 8),
                textView.widthAnchor.pin(greaterThanOrEqualToConstant: max(layout.textSize.width, layout.parentTextSize.width - 70)),
                textView.heightAnchor.pin(constant: layout.textSize.height),
                textView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
            ]
            let infoWidth = infoView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
            let maxSpace = infoWidth == 0 ? 70 : infoWidth + 12
            if layout.lastCharRect.maxX + maxSpace <= layout.textSize.width {
                layoutConstraint += [
                    textView.bottomAnchor.pin(to: infoView.bottomAnchor),
                    textView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12)
                ]
            } else if layout.lastCharRect.maxX + maxSpace <= Components.messageLayoutModel.defaults.messageWidth {
                layoutConstraint += [
                    textView.bottomAnchor.pin(to: infoView.bottomAnchor),
                    textView.trailingAnchor.pin(to: infoView.leadingAnchor, constant: -12 + (layout.textSize.width - layout.lastCharRect.maxX))
                ]
            } else {
                layoutConstraint += [
                    textView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                    textView.bottomAnchor.pin(to: infoView.topAnchor),
                ]
            }
        } else if options == .image {
            infoView.dateLabel.textColor = .white
            dateTickBackgroundView.isHidden = false
            
            layoutConstraint += [
                textView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                textView.topAnchor.pin(to: contentTopAnchor),
                textView.widthAnchor.pin(constant: 0),
                textView.heightAnchor.pin(constant: 0),

                bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                bubbleView.widthAnchor.pin(constant: attachmentsContainerSize.width + 4),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),

                attachmentView.topAnchor.pin(to: contentTopAnchor, constant: (layout.isForwarded || layout.hasReply) ? 8 : 2),
                attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -2),
            ]
        } else if options == .file || options == [.file, .image] || options == .voice {
            layoutConstraint += [
                textView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                textView.topAnchor.pin(to: contentTopAnchor),
                textView.widthAnchor.pin(constant: 0),
                textView.heightAnchor.pin(constant: 0),

                bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                bubbleView.widthAnchor.pin(constant: attachmentsContainerSize.width + 4),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),
                attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: 0),
                infoView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -17),
            ]
            if showName, !layout.isForwarded {
                layoutConstraint += [attachmentView.topAnchor.pin(to: nameLabel.bottomAnchor, constant: 8)]
            } else {
                layoutConstraint += [attachmentView.topAnchor.pin(to: bubbleViewTopAnchor, constant: layout.isForwarded ? 8 : 2)]
            }
        } else if layout.contentOptions.contains(.link), layout.attachmentCount.isEmpty {

            layoutConstraint += [

                bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                bubbleView.trailingAnchor.pin(to: infoView.trailingAnchor, constant: 12),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),
                bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.messageUserTitleSize.width + 24),

                textView.topAnchor.pin(to: contentTopAnchor, constant: layout.isForwarded ? 2 : 8),
                textView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                textView.heightAnchor.pin(constant: layout.textSize.height),
                textView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),

                linkView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 4),
                linkView.topAnchor.pin(to: textView.bottomAnchor, constant: 8),
                linkView.bottomAnchor.pin(to: infoView.topAnchor, constant: -4),
                linkView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -8),
                linkView.heightAnchor.pin(constant: linksContainerSize.height),
                infoView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -24)
            ]

            if layout.textSize.width > linksContainerSize.width + 8 {
                bubbleView.trailingAnchor.pin(to: textView.trailingAnchor, constant: 12)
            } else {
                bubbleView.widthAnchor.pin(constant: linksContainerSize.width + 8)
            }
        } else {
            dateTickBackgroundView.isHidden = layout.contentOptions.contains(.file)
            if !dateTickBackgroundView.isHidden {
                infoView.dateLabel.textColor = appearance.infoViewRevertColorOnBackgroundView
            } else {
                infoView.dateLabel.textColor = appearance.infoViewDateTextColor
            }
                
            layoutConstraint += [
                bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                bubbleView.widthAnchor.pin(constant: attachmentsContainerSize.width + 4),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),

                textView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                textView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                textView.heightAnchor.pin(constant: layout.textSize.height),
                textView.topAnchor.pin(to: contentTopAnchor, constant: layout.isForwarded ? 2 : 8),
                attachmentView.topAnchor.pin(to: textView.bottomAnchor, constant: 8),
                attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -2),
            ]
        }

        if layout.contentOptions.contains(.image) || layout.contentOptions.contains(.file) || layout.contentOptions.contains(.voice) {
            layoutConstraint += [
                attachmentView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 2),
                attachmentView.widthAnchor.pin(constant: attachmentsContainerSize.width),
                attachmentView.heightAnchor.pin(constant: attachmentsContainerSize.height),
            ]
        } else {
            layoutConstraint += [
                attachmentView.widthAnchor.pin(constant: 0),
                attachmentView.heightAnchor.pin(constant: 0),
            ]
        }
        
        if dateTickBackgroundView.isHidden {
            layoutConstraint += [
                infoView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                infoView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -8)
            ]
        } else {
            layoutConstraint += [
                dateTickBackgroundView.leadingAnchor.pin(to: infoView.leadingAnchor, constant: -6),
                dateTickBackgroundView.topAnchor.pin(to: infoView.topAnchor, constant: -3),
                dateTickBackgroundView.trailingAnchor.pin(to: infoView.trailingAnchor, constant: 6),
                dateTickBackgroundView.bottomAnchor.pin(to: infoView.bottomAnchor, constant: 3),
                infoView.trailingAnchor.pin(to: attachmentView.trailingAnchor, constant: -14),
                infoView.bottomAnchor.pin(to: attachmentView.bottomAnchor, constant: -13)
            ]
        }
        
        if layout.hasReactions {
            switch layout.reactionType {
            case .interactive:
                layoutConstraint += [
                    reactionView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 1),
                    reactionView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: 4)
                ]
            case .withTotalScore:
                layoutConstraint += [
                    reactionTotalView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    reactionTotalView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -4),
                    bubbleView.trailingAnchor.pin(greaterThanOrEqualTo: reactionTotalView.trailingAnchor)
                ]
            }
            let reactionBottomAnchor = layout.reactionType == .interactive ? reactionView.bottomAnchor : reactionTotalView.bottomAnchor
            if layout.hasThreadReply {
                layoutConstraint += [
                    replyCountView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 10),
                    replyCountView.topAnchor.pin(to: reactionBottomAnchor),
                    replyCountView.bottomAnchor.pin(to: contentView.bottomAnchor)
                ]
            } else {
                layoutConstraint += [reactionBottomAnchor.pin(to: contentView.bottomAnchor)]
            }
        } else if layout.hasThreadReply {
            layoutConstraint += [
                replyCountView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 10),
                replyCountView.topAnchor.pin(to: bubbleView.bottomAnchor),
                replyCountView.bottomAnchor.pin(to: contentView.bottomAnchor)
            ]
        } else {
            layoutConstraint += [bubbleView.bottomAnchor.pin(to: contentView.bottomAnchor)]
        }
        if layout.hasThreadReply {
            layoutConstraint += [
                replyArrowView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                replyArrowView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -16),
                replyArrowView.bottomAnchor.pin(to: replyCountView.centerYAnchor),
                replyArrowView.widthAnchor.pin(constant: 16)
            ]
        }
        return layoutConstraint
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        dateTickBackgroundView.isHidden = true
        infoView.dateLabel.textColor = .black
    }
}
