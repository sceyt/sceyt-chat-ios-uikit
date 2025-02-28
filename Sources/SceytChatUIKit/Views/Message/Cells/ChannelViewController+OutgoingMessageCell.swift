//
//  ChannelViewController+OutgoingMessageCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController {
    open class OutgoingMessageCell: MessageCell {
        
        open override var highlightMode: MessageCell.HighlightMode {
            didSet {
                switch highlightMode {
                case .reply:
                    bubbleView.backgroundColor = appearance.outgoingHighlightedBubbleColor
                    replyView.backgroundColor = appearance.outgoingHighlightedOverlayColor
                    linkView.arrangedSubviews.forEach { subview in
                        if subview is MessageCell.LinkPreviewView {
                            subview.backgroundColor = appearance.outgoingHighlightedOverlayColor
                        }
                    }
                case .search:
                    bubbleView.backgroundColor = appearance.outgoingHighlightedSearchResultColor
                    replyView.backgroundColor = appearance.outgoingHighlightedOverlaySearchResultColor
                    linkView.arrangedSubviews.forEach { subview in
                        if subview is MessageCell.LinkPreviewView {
                            subview.backgroundColor = appearance.outgoingHighlightedOverlaySearchResultColor
                        }
                    }
                case .none:
                    bubbleView.backgroundColor = appearance.outgoingBubbleColor
                    replyView.backgroundColor = appearance.outgoingReplyBackgroundColor
                    linkView.arrangedSubviews.forEach { subview in
                        if subview is MessageCell.LinkPreviewView {
                            subview.backgroundColor = appearance.outgoingLinkPreviewBackgroundColor
                        }
                    }
                }
                if data?.hasMediaAttachments == true {
                    attachmentOverlayView.backgroundColor = highlightMode == .reply ? appearance.outgoingHighlightedOverlayColor : appearance.outgoingHighlightedOverlaySearchResultColor
                    attachmentOverlayView.alpha = highlightMode == .none ? 0 : 0.5
                } else {
                    attachmentOverlayView.alpha = 0
                }
            }
        }
        
        open override func setup() {
            super.setup()
            replyArrowView.isFlipped = true
        }
        
        open override func layoutConstraints(layout: MessageLayoutModel) -> [NSLayoutConstraint] {
            defer {
                deliveryStatus = deliveryStatus
            }
            let attachmentsContainerSize = layout.attachmentsContainerSize
            var layoutConstraint = [NSLayoutConstraint]()
            UIView.performWithoutAnimation {
                bubbleView.backgroundColor = appearance.outgoingBubbleColor
                infoView.dateLabel.textColor = appearance.messageDateLabelAppearance.foregroundColor
                infoView.displayedLabel.textColor = infoView.dateLabel.textColor
                infoView.eyeView.tintColor = infoView.dateLabel.textColor
            }
            
            infoView.backgroundView.isHidden = true
            
            let hasVoicesOrFiles = layout.contentOptions.contains(.file) || layout.contentOptions.contains(.voice)
            let bubbleViewTopAnchor: NSLayoutYAxisAnchor
            let maxBubbleWidth = max(attachmentsContainerSize.width + 4, layout.textSize.width + 28, layout.measureSize.width)
            
            if layout.isForwarded {
                let anchors = Components.messageCellForwardView.Anchors.self
                layoutConstraint += [
                    forwardView.topAnchor.pin(to: containerView.topAnchor, constant: anchors.top),
                    forwardView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: anchors.leading),
                    forwardView.trailingAnchor.pin(lessThanOrEqualTo: bubbleView.trailingAnchor, constant: anchors.trailing),
                    forwardView.widthAnchor.pin(lessThanOrEqualToConstant: anchors.width)
                ]
                bubbleViewTopAnchor = forwardView.bottomAnchor
                
            } else if layout.hasReply {
                let anchors = Components.messageCellReplyView.Anchors.self
                layoutConstraint += [
                    replyView.topAnchor.pin(to: containerView.topAnchor, constant: anchors.top),
                    replyView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: anchors.leading),
                    replyView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: anchors.trailing),
                    replyView.widthAnchor.pin(lessThanOrEqualToConstant: anchors.width)
                ]
                bubbleViewTopAnchor = replyView.bottomAnchor
            } else {
                bubbleViewTopAnchor = bubbleView.topAnchor
            }
            
            if layout.contentOptions == .text {
                layoutConstraint += [
                    attachmentView.topAnchor.pin(to: bubbleViewTopAnchor),
                    bubbleView.leadingAnchor.pin(to: textLabel.leadingAnchor, constant: -12),
                    bubbleView.trailingAnchor.pin(to: containerView.trailingAnchor, constant: -12),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    
                    textLabel.topAnchor.pin(to: bubbleViewTopAnchor, constant: layout.isForwarded ? 2 : 8),
                    textLabel.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                    textLabel.heightAnchor.pin(constant: layout.textSize.height),
                ]
                
                let infoWidth = layout.infoViewMeasure.width
                let maxSpace = infoWidth == 0 ? 70 : infoWidth + 12
                if layout.lastCharRect.maxX + maxSpace <= layout.textSize.width {
                    layoutConstraint += [
                        textLabel.bottomAnchor.pin(to: infoView.bottomAnchor),
                        textLabel.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12)
                    ]
                } else if layout.lastCharRect.maxX + maxSpace <= Components.messageLayoutModel.defaults.messageWidth - 12 * 2 {
                    layoutConstraint += [
                        textLabel.bottomAnchor.pin(to: infoView.bottomAnchor),
                        textLabel.trailingAnchor.pin(lessThanOrEqualTo: infoView.leadingAnchor, constant: -12 + (layout.textSize.width - layout.lastCharRect.maxX))
                    ]
                } else {
                    layoutConstraint += [
                        textLabel.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                        textLabel.bottomAnchor.pin(to: infoView.topAnchor),
                    ]
                }
                layoutConstraint += [
                    infoView.leadingAnchor.pin(greaterThanOrEqualTo: bubbleView.leadingAnchor, constant: 10),
                    infoView.widthAnchor.pin(constant: infoWidth)
                ]
            } else if layout.contentOptions == .image {
                infoView.dateLabel.textColor = appearance.onOverlayColor
                infoView.displayedLabel.textColor = infoView.dateLabel.textColor
                infoView.eyeView.tintColor = infoView.dateLabel.textColor
                //            infoView.tickView.tintColor = appearance.infoViewRevertColorOnBackgroundView
                infoView.backgroundView.isHidden = false
                layoutConstraint += [
                    textLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    textLabel.topAnchor.pin(to: bubbleViewTopAnchor),
                    textLabel.widthAnchor.pin(constant: 0),
                    textLabel.heightAnchor.pin(constant: 0),
                    
                    bubbleView.trailingAnchor.pin(to: containerView.trailingAnchor, constant: -12),
                    bubbleView.widthAnchor.pin(constant: maxBubbleWidth),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    
                    attachmentView.topAnchor.pin(to: bubbleViewTopAnchor, constant: layout.hasReply ? 8 : layout.isForwarded ? hasVoicesOrFiles ? 0 : 8 : 2),
                    attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -2),
                ]
            } else if layout.contentOptions == .file || layout.contentOptions == [.file, .image] || layout.contentOptions == .voice {
                layoutConstraint += [
                    textLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    textLabel.topAnchor.pin(to: bubbleViewTopAnchor),
                    textLabel.widthAnchor.pin(constant: 0),
                    textLabel.heightAnchor.pin(constant: 0),
                    
                    bubbleView.trailingAnchor.pin(to: containerView.trailingAnchor, constant: -12),
                    bubbleView.widthAnchor.pin(constant: maxBubbleWidth),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    
                    attachmentView.topAnchor.pin(to: bubbleViewTopAnchor, constant: layout.hasReply ? 8 : layout.isForwarded ? hasVoicesOrFiles ? 0 : 8 : 2),
                    attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: 0),
                ]
            } else if layout.contentOptions.contains(.link), layout.attachments.isEmpty {
                
                layoutConstraint += [
                    bubbleView.leadingAnchor.pin(to: textLabel.leadingAnchor, constant: -12),
                    bubbleView.trailingAnchor.pin(to: containerView.trailingAnchor, constant: -12),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.linkViewMeasure.width + 24),
                    bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.infoViewMeasure.width + 24),
                    bubbleView.widthAnchor.pin(lessThanOrEqualToConstant: Components.messageLayoutModel.defaults.messageWidth).priority(.required),
                    
                    infoView.leadingAnchor.pin(greaterThanOrEqualTo: bubbleView.leadingAnchor, constant: 10),
                    
                    textLabel.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                    textLabel.topAnchor.pin(to: bubbleViewTopAnchor, constant: 8),
                    textLabel.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                    textLabel.heightAnchor.pin(constant: layout.textSize.height),
                    
                    linkView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    linkView.topAnchor.pin(to: textLabel.bottomAnchor, constant: 8),
                    //                linkView.bottomAnchor.pin(to: infoView.topAnchor, constant: -4),
                    linkView.trailingAnchor.pin(to: bubbleView.trailingAnchor),
                    linkView.heightAnchor.pin(constant: layout.linkViewMeasure.height),
                ]
                
                
                layoutConstraint += [ linkView.bottomAnchor.pin(to: infoView.topAnchor, constant: -4) ]
            } else {
                infoView.backgroundView.isHidden = layout.contentOptions.contains(.file)
                if !infoView.backgroundView.isHidden {
                    infoView.dateLabel.textColor = appearance.onOverlayColor
                    //                infoView.tickView.tintColor = appearance.infoViewRevertColorOnBackgroundView
                } else {
                    infoView.dateLabel.textColor = appearance.messageDateLabelAppearance.foregroundColor
                }
                infoView.displayedLabel.textColor = infoView.dateLabel.textColor
                infoView.eyeView.tintColor = infoView.dateLabel.textColor
                
                layoutConstraint += [
                    bubbleView.trailingAnchor.pin(to: containerView.trailingAnchor, constant: -12),
                    bubbleView.widthAnchor.pin(constant: maxBubbleWidth),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    
                    textLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                    textLabel.topAnchor.pin(to: bubbleViewTopAnchor, constant: layout.isForwarded ? 2 : 8),
                    textLabel.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                    textLabel.heightAnchor.pin(constant: layout.textSize.height),
                    
                    attachmentView.topAnchor.pin(to: textLabel.bottomAnchor, constant: 8),
                    attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -2),
                ]
            }
            
            if layout.contentOptions.contains(.image) || layout.contentOptions.contains(.file) || layout.contentOptions.contains(.voice) {
                layoutConstraint += [
                    attachmentView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 2).priority(.required),
                    attachmentView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -2).priority(.required),
                    attachmentView.heightAnchor.pin(constant: attachmentsContainerSize.height),
                ]
            } else {
                layoutConstraint += [
                    attachmentView.widthAnchor.pin(constant: 0),
                    attachmentView.heightAnchor.pin(constant: 0),
                ]
            }
            
            if infoView.backgroundView.isHidden {
                layoutConstraint += [
                    infoView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -10),
                    infoView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -8)
                ]
            } else {
                layoutConstraint += [
                    infoView.trailingAnchor.pin(to: attachmentView.trailingAnchor, constant: -12),
                    infoView.bottomAnchor.pin(to: attachmentView.bottomAnchor, constant: -9)
                ]
            }
            
            layoutConstraint += [
                avatarView.leadingAnchor.pin(to: containerView.leadingAnchor),
                avatarView.topAnchor.pin(to: containerView.topAnchor),
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
                layoutConstraint += [
                    reactionTotalView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    reactionTotalView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -4),
                    bubbleView.trailingAnchor.pin(greaterThanOrEqualTo: reactionTotalView.trailingAnchor),
                ]
                
                let reactionBottomAnchor = reactionTotalView.bottomAnchor
                if layout.hasThreadReply {
                    layoutConstraint += [
                        replyCountView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -10),
                        replyCountView.topAnchor.pin(to: reactionBottomAnchor),
                        replyCountView.bottomAnchor.pin(to: containerView.bottomAnchor)
                    ]
                } else {
                    layoutConstraint += [reactionBottomAnchor.pin(to: containerView.bottomAnchor)]
                }
            } else if layout.hasThreadReply {
                layoutConstraint += [
                    replyCountView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -10),
                    replyCountView.topAnchor.pin(to: bubbleView.bottomAnchor),
                    replyCountView.bottomAnchor.pin(to: containerView.bottomAnchor)
                ]
            } else {
                layoutConstraint += [bubbleView.bottomAnchor.pin(to: containerView.bottomAnchor)]
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
            infoView.backgroundView.isHidden = true
            infoView.dateLabel.textColor = appearance.messageDateLabelAppearance.foregroundColor
            infoView.displayedLabel.textColor = infoView.dateLabel.textColor
            infoView.eyeView.tintColor = infoView.dateLabel.textColor
        }
        
        open override class func measure(model: MessageLayoutModel, appearance: MessageCell.Appearance) -> CGSize {
            var forwardSize: CGSize
            var replySize: CGSize
            var textSize: CGSize = .zero
            var bubbleSize: CGSize
            var shouldShowDateTickBackground = false
            var hasVoicesOrFiles: Bool {
                model.contentOptions.contains(.file) || model.contentOptions.contains(.voice)
            }
            if model.isForwarded {
                let anchors = Components.messageCellForwardView.Anchors.self
                forwardSize = ForwardView.measure(model: model, appearance: appearance)
                forwardSize.width += anchors.leading + -anchors.trailing
                forwardSize.height += anchors.top
                forwardSize.width = min(forwardSize.width, anchors.width)
            } else {
                forwardSize = .zero
            }
            
            if !model.isForwarded, model.hasReply {
                let anchors = Components.messageCellReplyView.Anchors.self
                replySize = Components.messageCellReplyView.measure(model: model, appearance: appearance)
                replySize.width += anchors.leading + -anchors.trailing
                replySize.height += anchors.top
            } else {
                replySize = .zero
            }
            if model.contentOptions == .text {
                textSize = model.textSize
                textSize.width = max(textSize.width, model.parentTextSize.width - 70)
                bubbleSize = textSize
                let infoViewSize = model.infoViewMeasure
                let maxSpace = infoViewSize.width + 12
                
                if model.lastCharRect.maxX + maxSpace <= model.textSize.width {
                    
                } else if model.lastCharRect.maxX + maxSpace <= Components.messageLayoutModel.defaults.messageWidth - 12 * 2 {
                    bubbleSize.width += model.lastCharRect.maxX + maxSpace - model.textSize.width
                } else {
                    bubbleSize.height += infoViewSize.height
                }
                
                bubbleSize.width += 24
                bubbleSize.height += model.isForwarded ? 2 : 8
                bubbleSize.height += 8 //bottom
            } else if model.contentOptions == .image {
                shouldShowDateTickBackground = false
                textSize = .zero
                
                bubbleSize = model.attachmentsContainerSize
                bubbleSize.width += 4
                bubbleSize.height += 2 + (model.hasReply ? 8 : model.isForwarded ? hasVoicesOrFiles ? 0 : 8 : 2)
            }  else if model.contentOptions == .file || model.contentOptions == [.file, .image] || model.contentOptions == .voice {
                textSize = .zero
                bubbleSize = model.attachmentsContainerSize
                bubbleSize.width += 4
                bubbleSize.height += (model.hasReply ? 8 : model.isForwarded ? hasVoicesOrFiles ? 0 : 8 : 2)
            } else if model.contentOptions.contains(.link) {
                let linkSize = model.linkViewMeasure
                textSize = model.textSize
                textSize.width = max(textSize.width, model.parentTextSize.width - 70)
                bubbleSize = textSize
                bubbleSize.width = max(bubbleSize.width, linkSize.width)
                bubbleSize.height += linkSize.height
                bubbleSize.height += (model.hasReply ? 8 : model.isForwarded ? hasVoicesOrFiles ? 0 : 8 : 2)
                bubbleSize.height += 12 //padding
                bubbleSize.height += 12 //padding
                
                let infoViewSize = InfoView.measure(model: model, appearance: appearance)
                bubbleSize.height += infoViewSize.height
            } else {
                shouldShowDateTickBackground = false
                bubbleSize = model.attachmentsContainerSize
                bubbleSize.width += 4
                textSize = model.textSize
                textSize.height += model.isForwarded ? 2 : 8
                bubbleSize.height += textSize.height
                bubbleSize.width = max(bubbleSize.width, textSize.width)
                bubbleSize.height += 8 + 2
            }
            
            if shouldShowDateTickBackground  {
                bubbleSize.height += 8
            }
            
            if replySize != .zero {
                bubbleSize.height += replySize.height
                bubbleSize.width = max(bubbleSize.width, replySize.width)
            }
            if forwardSize != .zero {
                bubbleSize.height += forwardSize.height
                bubbleSize.width = max(bubbleSize.width, forwardSize.width)
            }
            
            if model.hasReactions {
                switch model.reactionType {
                case .interactive:
                    logger.debug("not implemented yet")
                case .withTotalScore:
                    let size = Components.messageCellReactionTotalView.measure(model: model, appearance: appearance)
                    bubbleSize.height += size.height - 4
                    bubbleSize.width = max(bubbleSize.width, size.width)
                }
            }
            
            if model.isLastDisplayedMessage {
                bubbleSize.height += Components.messageCellUnreadMessagesSeparatorView.measure(model: model, appearance: appearance).height
            }
            logger.debug("OutgoingMessageCell: measure messageId: \(model.message.id), measure: \(bubbleSize) body: \(model.message.body)")
            return bubbleSize
        }
    }
}
