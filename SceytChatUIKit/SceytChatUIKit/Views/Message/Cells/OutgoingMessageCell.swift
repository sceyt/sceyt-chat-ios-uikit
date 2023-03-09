//
//  OutgoingMessageCell.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit
import SceytChat

open class OutgoingMessageCell: MessageCell {
    
    open override var isHighlightedBubbleView: Bool {
        didSet {
            bubbleView.backgroundColor = isHighlightedBubbleView
            ? appearance.highlightedBubbleColor.out
            : appearance.bubbleColor.out
        }
    }

    open override func setup() {
        super.setup()
        replyArrowView.isFlipped = true
    }

    open override func layoutConstraints(layout: MessageLayoutModel) -> [NSLayoutConstraint] {

        var layoutConstraint = [NSLayoutConstraint]()

        bubbleView.backgroundColor = appearance.bubbleColor.out
        infoView.dateLabel.textColor = appearance.infoViewDateTextColor

        let bubbleViewTopAnchor: NSLayoutYAxisAnchor

        if layout.isForwarded {
            layoutConstraint += [
                forwardView.topAnchor.pin(to: unreadView.bottomAnchor, constant: 8),
                forwardView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                forwardView.trailingAnchor.pin(lessThanOrEqualTo: bubbleView.trailingAnchor, constant: -12),
                forwardView.widthAnchor.pin(lessThanOrEqualToConstant: Components.messageLayoutModel.defaults.messageWidth)
            ]
            bubbleViewTopAnchor = forwardView.bottomAnchor
            
        } else if layout.hasReply {
            layoutConstraint += [
                replyView.topAnchor.pin(to: unreadView.bottomAnchor, constant: 8),
                replyView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                replyView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                replyView.widthAnchor.pin(lessThanOrEqualToConstant: Components.messageLayoutModel.defaults.messageWidth)
            ]
            bubbleViewTopAnchor = replyView.bottomAnchor
        } else {
            bubbleViewTopAnchor = bubbleView.topAnchor
        }

        if layout.contentOptions == .text {
            layoutConstraint += [
                attachmentView.topAnchor.pin(to: bubbleViewTopAnchor),
                bubbleView.leadingAnchor.pin(to: textView.leadingAnchor, constant: -12),
                bubbleView.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -12),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),

                textView.topAnchor.pin(to: bubbleViewTopAnchor, constant: layout.isForwarded ? 2 : 8),
                textView.widthAnchor.pin(greaterThanOrEqualToConstant: max(layout.textSize.width, layout.parentTextSize.width - 70)),
                textView.heightAnchor.pin(constant: layout.textSize.height),
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
        } else if layout.contentOptions == .image {
            infoView.dateLabel.textColor = appearance.infoViewRevertColorOnBackgroundView
//            infoView.tickView.tintColor = appearance.infoViewRevertColorOnBackgroundView
            dateTickBackgroundView.isHidden = false
            layoutConstraint += [
                textView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                textView.topAnchor.pin(to: bubbleViewTopAnchor),
                textView.widthAnchor.pin(constant: 0),
                textView.heightAnchor.pin(constant: 0),

                bubbleView.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -12),
                bubbleView.widthAnchor.pin(constant: attachmentsContainerSize.width + 4),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),

                attachmentView.topAnchor.pin(to: bubbleViewTopAnchor, constant: (layout.hasReply || layout.isForwarded) ? 8 : 2),
                attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -2),
            ]
        } else if layout.contentOptions == .file || layout.contentOptions == [.file, .image] || layout.contentOptions == .voice {
            layoutConstraint += [
                textView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                textView.topAnchor.pin(to: bubbleViewTopAnchor),
                textView.widthAnchor.pin(constant: 0),
                textView.heightAnchor.pin(constant: 0),

                bubbleView.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -12),
                bubbleView.widthAnchor.pin(constant: attachmentsContainerSize.width + 4),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),

                attachmentView.topAnchor.pin(to: bubbleViewTopAnchor, constant: (layout.hasReply || layout.isForwarded) ? 8 : 2),
                attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: 0),
            ]
        } else if layout.contentOptions.contains(.link), layout.attachmentCount.isEmpty {

            layoutConstraint += [
                bubbleView.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -12),
                bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: linksContainerSize.width + 8),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),

                bubbleView.leadingAnchor.pin(to: textView.leadingAnchor, constant: -12),

                textView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                textView.topAnchor.pin(to: bubbleViewTopAnchor, constant: 8),
                textView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                textView.heightAnchor.pin(constant: layout.textSize.height),

                linkView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 4),
                linkView.topAnchor.pin(to: textView.bottomAnchor, constant: 8),
                linkView.bottomAnchor.pin(to: infoView.topAnchor, constant: -4),
                linkView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -8),
                linkView.heightAnchor.pin(constant: linksContainerSize.height),
            ]
            if layout.textSize.width > linksContainerSize.width + 8 {
                bubbleView.leadingAnchor.pin(to: textView.leadingAnchor, constant: -12)
            } else {
                bubbleView.leadingAnchor.pin(to: linkView.leadingAnchor, constant: -8)
            }
        } else {
            dateTickBackgroundView.isHidden = layout.contentOptions.contains(.file)
            if !dateTickBackgroundView.isHidden {
                infoView.dateLabel.textColor = appearance.infoViewRevertColorOnBackgroundView
//                infoView.tickView.tintColor = appearance.infoViewRevertColorOnBackgroundView
            } else {
                infoView.dateLabel.textColor = appearance.infoViewDateTextColor
            }
            
            layoutConstraint += [
                bubbleView.trailingAnchor.pin(to: contentView.trailingAnchor, constant: -12),
                bubbleView.widthAnchor.pin(constant: attachmentsContainerSize.width + 4),
                bubbleView.topAnchor.pin(to: unreadView.bottomAnchor),

                textView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                textView.topAnchor.pin(to: bubbleViewTopAnchor, constant: layout.isForwarded ? 2 : 8),
                textView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                textView.heightAnchor.pin(constant: layout.textSize.height),

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
                infoView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -10),
                infoView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -8)
            ]
        } else {
            layoutConstraint += [
                dateTickBackgroundView.leadingAnchor.pin(to: infoView.leadingAnchor, constant: -6),
                dateTickBackgroundView.topAnchor.pin(to: infoView.topAnchor, constant: -3),
                dateTickBackgroundView.trailingAnchor.pin(to: infoView.trailingAnchor, constant: 6),
                dateTickBackgroundView.bottomAnchor.pin(to: infoView.bottomAnchor, constant: 3),
                infoView.trailingAnchor.pin(to: attachmentView.trailingAnchor, constant: -12),
                infoView.bottomAnchor.pin(to: attachmentView.bottomAnchor, constant: -13)
            ]
        }
        
        layoutConstraint += [
            avatarView.leadingAnchor.pin(to: contentView.leadingAnchor),
            avatarView.topAnchor.pin(to: unreadView.bottomAnchor),
            avatarView.widthAnchor.pin(constant: 0),
            avatarView.heightAnchor.pin(constant: 0)
        ]
        layoutConstraint += [
            nameLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor),
            nameLabel.topAnchor.pin(to: bubbleView.topAnchor),
            nameLabel.widthAnchor.pin(constant: 0),
            nameLabel.heightAnchor.pin(constant: 0)
        ]

        if layout.hasReactions {
            switch layout.reactionType {
            case .interactive:
                layoutConstraint += [
                    reactionView.trailingAnchor.pin(to: bubbleView.trailingAnchor),
                    reactionView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: 4)
                ]
            case .withTotalScore:
                layoutConstraint += [
                    reactionTotalView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    reactionTotalView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -4),
                    bubbleView.trailingAnchor.pin(greaterThanOrEqualTo: reactionTotalView.trailingAnchor),
                ]
            }
            let reactionBottomAnchor = layout.reactionType == .interactive ? reactionView.bottomAnchor : reactionTotalView.bottomAnchor
            if layout.hasThreadReply {
                layoutConstraint += [
                    replyCountView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -10),
                    replyCountView.topAnchor.pin(to: reactionBottomAnchor),
                    replyCountView.bottomAnchor.pin(to: contentView.bottomAnchor)
                ]
            } else {
                layoutConstraint += [reactionBottomAnchor.pin(to: contentView.bottomAnchor)]
            }
        } else if layout.hasThreadReply {
            layoutConstraint += [
                replyCountView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -10),
                replyCountView.topAnchor.pin(to: bubbleView.bottomAnchor),
                replyCountView.bottomAnchor.pin(to: contentView.bottomAnchor)
            ]
        } else {
            layoutConstraint += [bubbleView.bottomAnchor.pin(to: contentView.bottomAnchor)]
        }

        if layout.hasThreadReply {
            layoutConstraint += [
                replyArrowView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: 1),
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
