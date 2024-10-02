//
//  MessageInfoViewController+MessageCell.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInfoViewController {
    open class MessageCell: TableViewCell {
        open lazy var appearance = Components.messageInfoViewController.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open lazy var bubbleView = Components.channelOutgoingMessageCell.init().withoutAutoresizingMask
        
        open lazy var sentLabel = UILabel()
        open lazy var sizeLabel = UILabel()
        
        open lazy var sentValueLabel = UILabel()
        open lazy var sizeValueLabel = UILabel()
        
        open lazy var sentHStack = UIStackView(row: [sentLabel, sentValueLabel], spacing: 4)
        open lazy var sizeHStack = UIStackView(row: [sizeLabel, sizeValueLabel], spacing: 4)
        
        open lazy var vStack = UIStackView(column: [sentHStack, sizeHStack],
                                           spacing: 4,
                                           distribution: .fillProportionally,
                                           alignment: .leading)
            .withoutAutoresizingMask
        
        public var bubbleHeight: NSLayoutConstraint?
        public var bubbleTop: NSLayoutConstraint?
        public var bubbleBottom: NSLayoutConstraint?
        
        var data: MessageLayoutModel! {
            didSet {
                guard let data else { return }
                bubbleView.parentAppearance = appearance.messageCellAppearance
                bubbleView.data = data
                if let bubbleTop, let bubbleBottom, let bubbleHeight {
                    bubbleTop.constant = 12 - data.contentInsets.top
                    bubbleHeight.constant = data.measureSize.height
                    bubbleBottom.constant = -12 + data.contentInsets.bottom
                } else {
                    setupLayout()
                }
                sentValueLabel.text = appearance.messageDateFormatter.format(data.message.createdAt)
                if let fileSize = data.attachments.first?.fileSize(using: appearance.attachmentSizeFormatter) {
                    sizeHStack.isHidden = false
                    sizeValueLabel.text = fileSize
                } else {
                    sizeHStack.isHidden = true
                }
            }
        }
        
        override open func setup() {
            super.setup()
            
            selectionStyle = .none
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(bubbleView)
            contentView.addSubview(vStack)
            bubbleView.pin(to: contentView, anchors: [.leading(4, .greaterThanOrEqual), .trailing(-4)])
            vStack.pin(to: contentView, anchors: [.leading(16), .trailing(-16), .bottom(-16)])
            
            if let data {
                bubbleTop = bubbleView.topAnchor.pin(to: contentView.topAnchor, constant: 12 - data.contentInsets.top)
                bubbleBottom = bubbleView.bottomAnchor.pin(to: vStack.topAnchor, constant: -12 + data.contentInsets.bottom)
                bubbleHeight = bubbleView.heightAnchor.pin(constant: data.measureSize.height)
            }
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.cellBackgroundColor
            
            sentLabel.text = appearance.sentLabelText
            sizeLabel.text = appearance.sizeLabelText
            
            sentLabel.font = appearance.descriptionTitleLabelAppearance.font
            sentLabel.textColor = appearance.descriptionTitleLabelAppearance.foregroundColor
            sizeLabel.font = appearance.descriptionTitleLabelAppearance.font
            sizeLabel.textColor = appearance.descriptionTitleLabelAppearance.foregroundColor
            
            sentValueLabel.font = appearance.descriptionValueLabelAppearance.font
            sentValueLabel.textColor = appearance.descriptionValueLabelAppearance.foregroundColor
            sizeValueLabel.font = appearance.descriptionValueLabelAppearance.font
            sizeValueLabel.textColor = appearance.descriptionValueLabelAppearance.foregroundColor
        }
    }
}
