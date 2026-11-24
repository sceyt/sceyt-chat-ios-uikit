//
//  MessageCell+UnsupportedMessageView.swift
//  SceytChatUIKit
//
//  Created by Sceyt LLC.
//  Copyright © 2025 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell {
    open class UnsupportedMessageView: View, MessageCellMeasurable {
        open lazy var messageLabel: UITextView = {
            let textView = UITextView()
                .withoutAutoresizingMask
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.backgroundColor = .clear
            textView.isUserInteractionEnabled = true
            return textView
        }()

        open var data: MessageLayoutModel? {
            didSet {
                guard let data = data else {
                    isHidden = true
                    return
                }

                guard data.contentOptions.contains(.unsupported) else {
                    isHidden = true
                    return
                }

                messageLabel.attributedText = Components.messageCell.appearance.unsupportedMessageFormatter.format(data.message)
                isHidden = false
                // DEBUG(unsupported-layout): remove after diagnosis
                logger.info("[UnsupportedMsg] bind id=\(data.message.id) tid=\(data.message.tid) incoming=\(data.message.incoming) measure=\(data.unsupportedViewMeasure) options=\(data.contentOptions.rawValue) attachments=\(data.attachments.count) textLen=\(messageLabel.attributedText?.length ?? -1)")
            }
        }

        override open func setup() {
            super.setup()

            layer.cornerRadius = 16
        }

        override open func setupLayout() {
            super.setupLayout()

            addSubview(messageLabel)
            messageLabel.pin(to: self, anchors: [.leading(8.0), .trailing(-8.0), .top, .bottom])
        }

        // DEBUG(unsupported-layout): remove after diagnosis
        override open func layoutSubviews() {
            super.layoutSubviews()
            guard !isHidden, let data else { return }
            let fits = messageLabel.sizeThatFits(CGSize(width: messageLabel.bounds.width, height: .greatestFiniteMagnitude))
            logger.info("[UnsupportedMsg] layout id=\(data.message.id) view=\(frame) label=\(messageLabel.frame) labelContent=\(messageLabel.contentSize) labelFits=\(fits) measure=\(data.unsupportedViewMeasure) superview=\(superview?.bounds ?? .zero) clips=\(superview?.clipsToBounds ?? false)")
        }

        override open func setupAppearance() {
            super.setupAppearance()

            backgroundColor = .clear
        }

        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            guard model.contentOptions.contains(.unsupported) else {
                return .zero
            }

            let contentMaxWidth = Components.messageLayoutModel.defaults.messageWidth - 16.0
            let attributedString = SceytChatUIKit.shared.formatters.unsupportedMessageFormatter.format(model.message)

            let config = TextSizeMeasure.Config(
                restrictingWidth: contentMaxWidth,
                maximumNumberOfLines: 0,
                font: .systemFont(ofSize: 16.0),
                lastFragmentUsedRect: false
            )

            let textSize = TextSizeMeasure.calculateSize(of: attributedString, config: config).textSize
            let height = 8.0 + ceil(textSize.height) // top + bottom padding

            let result = CGSize(width: textSize.width + 16.0, height: ceil(height))
            // DEBUG(unsupported-layout): remove after diagnosis
            let boundingRect = attributedString.boundingRect(
                with: CGSize(width: contentMaxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            logger.info("[UnsupportedMsg] measure id=\(model.message.id) tid=\(model.message.tid) messageWidth=\(Components.messageLayoutModel.defaults.messageWidth) maxWidth=\(contentMaxWidth) textLen=\(attributedString.length) textSize=\(textSize) boundingRect=\(boundingRect.size) result=\(result) text=\"\(attributedString.string)\"")
            return result
        }
    }
}
