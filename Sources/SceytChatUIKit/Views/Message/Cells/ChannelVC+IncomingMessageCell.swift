//
//  ChannelViewController+IncomingMessageCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelViewController {
    open class IncomingMessageCell: MessageCell {
        
        open override var highlightMode: MessageCell.HighlightMode {
            didSet {
                switch highlightMode {
                case .reply:
                    bubbleView.backgroundColor = appearance.highlightedBubbleColor.in
                case .search:
                    bubbleView.backgroundColor = appearance.highlightedSearchResultColor.in
                case .none:
                    bubbleView.backgroundColor = appearance.bubbleColor.in
                }
                if data?.hasMediaAttachments == true {
                    attachmentOverlayView.backgroundColor = appearance.highlightedOverlayColor.in
                    attachmentOverlayView.alpha = highlightMode == .reply ? 1 : 0
                } else {
                    attachmentOverlayView.alpha = 0
                }
            }
        }
        
        open override func layoutConstraints(layout: MessageLayoutModel) -> [NSLayoutConstraint] {
            let attachmentsContainerSize = layout.attachmentsContainerSize
            var layoutConstraint = [NSLayoutConstraint]()
            UIView.performWithoutAnimation {
                bubbleView.backgroundColor = appearance.bubbleColor.in
                infoView.dateLabel.textColor = appearance.infoViewDateTextColor
                infoView.displayedLabel.textColor = infoView.dateLabel.textColor
                infoView.eyeView.tintColor = infoView.dateLabel.textColor
                infoView.tickView.isHidden = true
            }
            
            let hasName = layout.contentOptions.contains(.name)
            let hasVoicesOrFiles = layout.contentOptions.contains(.file) || layout.contentOptions.contains(.voice)
            var options = layout.contentOptions
            options.remove(.name)
            let showName = hasName && showSenderInfo
            let maxBubbleWidth = max(attachmentsContainerSize.width + 4, layout.textSize.width + 28, layout.measureSize.width)
            
            let bubbleViewTopAnchor: NSLayoutYAxisAnchor
            let contentTopAnchor: NSLayoutYAxisAnchor
            if layout.isForwarded {
                let anchors = Components.messageCellForwardView.Anchors.self
                let topAnchor = showSenderInfo ? nameLabel.bottomAnchor : containerView.topAnchor
                layoutConstraint += [
                    forwardView.topAnchor.pin(to: topAnchor, constant: anchors.top),
                    forwardView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: anchors.leading),
                    forwardView.trailingAnchor.pin(lessThanOrEqualTo: bubbleView.trailingAnchor, constant: anchors.trailing),
                    forwardView.widthAnchor.pin(lessThanOrEqualToConstant: anchors.width)
                ]
                bubbleViewTopAnchor = forwardView.bottomAnchor
                contentTopAnchor = forwardView.bottomAnchor
            } else if layout.hasReply {
                let topAnchor = showSenderInfo ? nameLabel.bottomAnchor : containerView.topAnchor
                let anchors = Components.messageCellReplyView.Anchors.self
                layoutConstraint += [
                    replyView.topAnchor.pin(to: topAnchor, constant: anchors.top),
                    replyView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: anchors.leading),
                    replyView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: anchors.trailing),
                    replyView.widthAnchor.pin(lessThanOrEqualToConstant: anchors.width)
                ]
                bubbleViewTopAnchor = replyView.bottomAnchor
                contentTopAnchor = replyView.bottomAnchor
            } else {
                bubbleViewTopAnchor = bubbleView.topAnchor
                contentTopAnchor = showName ? nameLabel.bottomAnchor : bubbleViewTopAnchor
            }
            
            if showName {
                layoutConstraint += [
                    avatarView.leadingAnchor.pin(to: containerView.leadingAnchor, constant: 12),
                    avatarView.topAnchor.pin(to: containerView.topAnchor),
                    avatarView.widthAnchor.pin(constant: 36),
                    avatarView.heightAnchor.pin(constant: 36),
                    
                    nameLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                    nameLabel.topAnchor.pin(to: bubbleView.topAnchor, constant: 8),
                    nameLabel.widthAnchor.pin(constant: layout.messageUserTitleSize.width).priority(.defaultLow),
                    nameLabel.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12).priority(.required)
                ]
            } else if hasName && !showSenderInfo {
                layoutConstraint += [
                    avatarView.leadingAnchor.pin(to: containerView.leadingAnchor, constant: 12),
                    avatarView.topAnchor.pin(to: containerView.topAnchor),
                    avatarView.widthAnchor.pin(constant: 36),
                    avatarView.heightAnchor.pin(constant: 36),
                    
                    nameLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    nameLabel.topAnchor.pin(to: bubbleViewTopAnchor),
                    nameLabel.widthAnchor.pin(constant: 0),
                    nameLabel.heightAnchor.pin(constant: 0)
                ]
            } else {
                layoutConstraint += [
                    avatarView.leadingAnchor.pin(to: containerView.leadingAnchor),
                    avatarView.topAnchor.pin(to: containerView.topAnchor),
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
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: (showName ? layout.messageUserTitleSize.width : 0) + 24),
                    bubbleView.widthAnchor.pin(lessThanOrEqualToConstant: Components.messageLayoutModel.defaults.messageWidth).priority(.required),
                    
                    textLabel.topAnchor.pin(to: contentTopAnchor, constant: (layout.isForwarded || showSenderInfo) ? 2 : 8),
                    textLabel.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                    textLabel.heightAnchor.pin(constant: layout.textSize.height),
                    textLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
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
                        textLabel.trailingAnchor.pin(to: infoView.leadingAnchor, constant: -12 + (layout.textSize.width - layout.lastCharRect.maxX))
                    ]
                } else {
                    layoutConstraint += [
                        textLabel.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                        textLabel.bottomAnchor.pin(to: infoView.topAnchor),
                    ]
                }
                layoutConstraint += [
                    infoView.trailingAnchor.pin(lessThanOrEqualTo: bubbleView.trailingAnchor, constant: -10),
                    infoView.widthAnchor.pin(constant: infoWidth)
                ]
            } else if options == .image {
                infoView.dateLabel.textColor = appearance.infoViewRevertColorOnBackgroundView
                infoView.displayedLabel.textColor = infoView.dateLabel.textColor
                infoView.eyeView.tintColor = infoView.dateLabel.textColor
                dateTickBackgroundView.isHidden = false
                
                layoutConstraint += [
                    textLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    textLabel.topAnchor.pin(to: contentTopAnchor),
                    textLabel.widthAnchor.pin(constant: 0),
                    textLabel.heightAnchor.pin(constant: 0),
                    
                    bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                    bubbleView.widthAnchor.pin(constant: maxBubbleWidth),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    
                    attachmentView.topAnchor.pin(to: contentTopAnchor, constant: (layout.isForwarded || layout.hasReply || showSenderInfo) ? 8 : 2),
                    attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -2),
                ]
            } else if options == .file || options == [.file, .image] || options == .voice {
                layoutConstraint += [
                    textLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    textLabel.topAnchor.pin(to: contentTopAnchor),
                    textLabel.widthAnchor.pin(constant: 0),
                    textLabel.heightAnchor.pin(constant: 0),
                    
                    bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                    bubbleView.widthAnchor.pin(constant: maxBubbleWidth),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    attachmentView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: 0),
                    infoView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -17),
                ]
                if showName, !layout.isForwarded, !layout.hasReply {
                    layoutConstraint += [attachmentView.topAnchor.pin(to: nameLabel.bottomAnchor, constant: 2)]
                } else {
                    layoutConstraint += [attachmentView.topAnchor.pin(to: bubbleViewTopAnchor, constant: layout.isForwarded ? hasVoicesOrFiles ? 0 : 8 : 2)]
                }
            } else if layout.contentOptions.contains(.link), layout.attachments.isEmpty {
                layoutConstraint += [
                    bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                    bubbleView.trailingAnchor.pin(to: infoView.trailingAnchor, constant: 12),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.messageUserTitleSize.width + 24),
                    bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.linkViewMeasure.width + 24),
                    bubbleView.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width + 24),
                    bubbleView.widthAnchor.pin(lessThanOrEqualToConstant: Components.messageLayoutModel.defaults.messageWidth).priority(.required),
                    
                    textLabel.topAnchor.pin(to: contentTopAnchor, constant: (layout.isForwarded || showSenderInfo) ? 2 : 8),
                    textLabel.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                    textLabel.heightAnchor.pin(constant: layout.textSize.height),
                    textLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                    
                    linkView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    linkView.topAnchor.pin(to: textLabel.bottomAnchor, constant: 8),
                    linkView.trailingAnchor.pin(to: bubbleView.trailingAnchor),
                    linkView.heightAnchor.pin(constant: layout.linkViewMeasure.height),
                    
                    infoView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -24)
                ]
                
                layoutConstraint += [ linkView.bottomAnchor.pin(lessThanOrEqualTo: infoView.topAnchor, constant: -4) ]
                
            } else {
                dateTickBackgroundView.isHidden = layout.contentOptions.contains(.file)
                if !dateTickBackgroundView.isHidden {
                    infoView.dateLabel.textColor = appearance.infoViewRevertColorOnBackgroundView
                } else {
                    infoView.dateLabel.textColor = appearance.infoViewDateTextColor
                }
                infoView.displayedLabel.textColor = infoView.dateLabel.textColor
                infoView.eyeView.tintColor = infoView.dateLabel.textColor
                
                layoutConstraint += [
                    bubbleView.leadingAnchor.pin(to: avatarView.trailingAnchor, constant: 10),
                    bubbleView.widthAnchor.pin(constant: maxBubbleWidth),
                    bubbleView.topAnchor.pin(to: containerView.topAnchor),
                    
                    textLabel.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 12),
                    textLabel.widthAnchor.pin(greaterThanOrEqualToConstant: layout.textSize.width),
                    textLabel.heightAnchor.pin(constant: layout.textSize.height),
                    textLabel.topAnchor.pin(to: contentTopAnchor, constant: (layout.isForwarded || showSenderInfo) ? 2 : 8),
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
            
            if dateTickBackgroundView.isHidden {
                layoutConstraint += [
                    infoView.trailingAnchor.pin(to: bubbleView.trailingAnchor, constant: -12),
                    infoView.bottomAnchor.pin(to: bubbleView.bottomAnchor, constant: -8)
                ]
            } else {
                let infoAnchorView = (layout.contentOptions.contains(.link) && layout.attachments.isEmpty) ? linkView : attachmentView
                layoutConstraint += [
                    dateTickBackgroundView.leadingAnchor.pin(to: infoView.leadingAnchor, constant: -6),
                    dateTickBackgroundView.topAnchor.pin(to: infoView.topAnchor, constant: -3),
                    dateTickBackgroundView.trailingAnchor.pin(to: infoView.trailingAnchor, constant: 6),
                    dateTickBackgroundView.bottomAnchor.pin(to: infoView.bottomAnchor, constant: 3),
                    infoView.trailingAnchor.pin(to: infoAnchorView.trailingAnchor, constant: -12),
                    infoView.bottomAnchor.pin(to: infoAnchorView.bottomAnchor, constant: -9)
                ]
            }
            
            if layout.hasReactions {
                layoutConstraint += [
                    reactionTotalView.leadingAnchor.pin(to: bubbleView.leadingAnchor),
                    reactionTotalView.topAnchor.pin(to: bubbleView.bottomAnchor, constant: -4),
                    bubbleView.trailingAnchor.pin(greaterThanOrEqualTo: reactionTotalView.trailingAnchor)
                ]
                let reactionBottomAnchor = reactionTotalView.bottomAnchor
                if layout.hasThreadReply {
                    layoutConstraint += [
                        replyCountView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 10),
                        replyCountView.topAnchor.pin(to: reactionBottomAnchor),
                        replyCountView.bottomAnchor.pin(to: containerView.bottomAnchor)
                    ]
                } else {
                    layoutConstraint += [reactionBottomAnchor.pin(to: containerView.bottomAnchor)]
                }
            } else if layout.hasThreadReply {
                layoutConstraint += [
                    replyCountView.leadingAnchor.pin(to: bubbleView.leadingAnchor, constant: 10),
                    replyCountView.topAnchor.pin(to: bubbleView.bottomAnchor),
                    replyCountView.bottomAnchor.pin(to: containerView.bottomAnchor)
                ]
            } else {
                layoutConstraint += [bubbleView.bottomAnchor.pin(to: containerView.bottomAnchor)]
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
            infoView.dateLabel.textColor = appearance.infoViewDateTextColor
            infoView.displayedLabel.textColor = infoView.dateLabel.textColor
            infoView.eyeView.tintColor = infoView.dateLabel.textColor
        }
        
        open override class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            var forwardSize: CGSize
            var replySize: CGSize
            var textSize: CGSize = .zero
            var bubbleSize: CGSize
            var userNameSize: CGSize
            
            let hasName = model.contentOptions.contains(.name)
            let hasVoicesOrFiles = model.contentOptions.contains(.file) || model.contentOptions.contains(.voice)
            var options = model.contentOptions
            options.remove(.name)
            let showName = hasName && model.showUserInfo
            
            if model.isForwarded {
                let anchors = Components.messageCellForwardView.Anchors.self
                forwardSize = Components.messageCellForwardView.measure(model: model, appearance: appearance)
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
            
            if showName {
                let text = SceytChatUIKit.shared.formatters.userNameFormatter.format(model.message.user)
                
                userNameSize = TextSizeMeasure
                    .calculateSize(
                        of: text,
                        config: .init(
                            maximumNumberOfLines: 1,
                            font: appearance.titleFont,
                            lastFragmentUsedRect: false
                        )).textSize
                userNameSize.width = min(userNameSize.width, model.messageUserTitleSize.width)
                userNameSize.height += 8
            } else {
                userNameSize = .zero
            }
            
            if options == .text {
                textSize = model.textSize
                textSize.width = max(textSize.width, model.parentTextSize.width - 70)
                textSize.height += (model.isForwarded || showName) ? 2 : 8
                bubbleSize = textSize
                bubbleSize.width += 10 + 12
                bubbleSize.width = max(bubbleSize.width, (showName ? model.messageUserTitleSize.width : 0) + 24)
                
                let infoViewSize = InfoView.measure(model: model, appearance: appearance)
                let maxSpace = infoViewSize.width + 12
                if model.lastCharRect.maxX + maxSpace <= model.textSize.width {
                    
                } else if model.lastCharRect.maxX + maxSpace <= Components.messageLayoutModel.defaults.messageWidth - 12 * 2 {
                    
                } else {
                    bubbleSize.height += infoViewSize.height
                }
                
                bubbleSize.width += 24
                bubbleSize.height += 8 //bottom
            } else if options == .image {
                textSize = .zero
                bubbleSize = model.attachmentsContainerSize
                bubbleSize.width += 4
                bubbleSize.height += 2 + ((model.isForwarded || model.hasReply || model.showUserInfo) ? 8 : 2)
                
            } else if options == .file || options == [.file, .image] || options == .voice {
                textSize = .zero
                bubbleSize = model.attachmentsContainerSize
                bubbleSize.width += 4
                if showName, !model.isForwarded, model.hasReply {
                    bubbleSize.height += 2
                } else {
                    bubbleSize.height += model.isForwarded ? hasVoicesOrFiles ? 0 : 8 : 2
                }
            } else if options.contains(.link) {
                let linkSize = model.linkViewMeasure
                textSize = model.textSize
                textSize.width = max(textSize.width, model.parentTextSize.width - 70)
                bubbleSize = textSize
                bubbleSize.width = max(bubbleSize.width, linkSize.width)
                bubbleSize.height += linkSize.height
                if showName, !model.isForwarded, model.hasReply {
                    bubbleSize.height += 2
                } else {
                    bubbleSize.height += model.isForwarded ? hasVoicesOrFiles ? 0 : 8 : 2
                }
                bubbleSize.height += 12 //padding
                if userNameSize == .zero {
                    bubbleSize.height += 18
                } else {
                    bubbleSize.height += 2
                }
                
                let infoViewSize = InfoView.measure(model: model, appearance: appearance)
                bubbleSize.height += infoViewSize.height
                logger.debug("[LINK SIZE] \(model.message.id), \(bubbleSize.height)")
            } else {
                bubbleSize = model.attachmentsContainerSize
                bubbleSize.width += 4
                textSize = model.textSize
                textSize.height += (model.isForwarded || model.showUserInfo) ? 2 : 8
                bubbleSize.height += textSize.height
                bubbleSize.width = max(bubbleSize.width, textSize.width)
                bubbleSize.height += (model.textSize.height > 0 && model.showUserInfo) ? 8 : 2
                bubbleSize.height += 8//Attachment padding
            }
            logger.debug("IncomingMessageCell: measure 1 messageId: \(model.message.id), measure: \(bubbleSize) body: \(model.message.body)")
            if replySize != .zero {
                bubbleSize.height += replySize.height
                bubbleSize.width = max(bubbleSize.width, replySize.width)
            }
            if forwardSize != .zero {
                bubbleSize.height += forwardSize.height
                bubbleSize.width = max(bubbleSize.width, forwardSize.width)
            }
            if userNameSize != .zero {
                bubbleSize.height += userNameSize.height
                bubbleSize.width = max(bubbleSize.width, userNameSize.width)
            }
            logger.debug("IncomingMessageCell: measure 2 messageId: \(model.message.id), measure: \(bubbleSize) body: \(model.message.body)")
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
            logger.debug("IncomingMessageCell: measure messageId: \(model.message.id), measure: \(bubbleSize) body: \(model.message.body)")
            return bubbleSize
        }
    }
}
