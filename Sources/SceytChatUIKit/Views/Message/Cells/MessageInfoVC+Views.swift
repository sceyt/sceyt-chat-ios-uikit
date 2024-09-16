//
//  MessageInfoVC+Views.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageInfoVC {
    open class HeaderView: TableViewHeaderFooterView {
        open lazy var appearance = MessageInfoVC.appearance
        
        open lazy var label = ContentInsetLabel().withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            
            label.edgeInsets = .init(top: 8, left: 0, bottom: 8, right: 0)
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(label)
            label.pin(to: contentView)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            label.font = appearance.headerFont
            label.textColor = appearance.headerColor
        }
    }

    open class MessageCell: TableViewCell {
        open lazy var appearance = MessageInfoVC.appearance
        
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
                bubbleView.data = data
                if let bubbleTop, let bubbleBottom, let bubbleHeight {
                    bubbleTop.constant = 12 - data.contentInsets.top
                    bubbleHeight.constant = data.measureSize.height
                    bubbleBottom.constant = -12 + data.contentInsets.bottom
                } else {
                    setupLayout()
                }
                sentValueLabel.text = SceytChatUIKit.shared.formatters.messageInfoDateFormatter.format(data.message.createdAt)
                if let fileSize = data.attachments.first?.fileSize {
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
            sentLabel.text = L10n.Message.Info.sent
            sizeLabel.text = L10n.Message.Info.size
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
            
            sentLabel.font = appearance.infoFont
            sentLabel.textColor = appearance.infoColor
            sizeLabel.font = appearance.infoFont
            sizeLabel.textColor = appearance.infoColor
            
            sentValueLabel.font = appearance.infoValueFont
            sentValueLabel.textColor = appearance.infoValueColor
            sizeValueLabel.font = appearance.infoValueFont
            sizeValueLabel.textColor = appearance.infoValueColor
        }
    }
    
    open class MarkerCell: TableViewCell {
        open lazy var appearance = MessageInfoVC.appearance
        
        open lazy var avatarView = Components.circleImageView.init()
            .contentMode(.scaleAspectFill)
        
        open lazy var nameLabel = UILabel()
        
        open lazy var dateTimeLabel = UILabel()
            .contentCompressionResistancePriorityH(.required)
            .contentHuggingPriorityH(.required)

        open lazy var hStack = UIStackView(row: [avatarView, nameLabel, dateTimeLabel],
                                           spacing: 12, alignment: .center)
            .withoutAutoresizingMask
        
        open var imageTask: Cancellable?
        
        var data: ChatMessage.Marker! {
            didSet {
                guard let data,
                      let user = data.user else { return }
                imageTask = Components.avatarBuilder.loadAvatar(into: avatarView.imageView, for: user)
                nameLabel.text = user.displayName
                dateTimeLabel.text = SceytChatUIKit.shared.formatters.mediaPreviewDateFormatter.format(data.createdAt)
            }
        }
        
        open override func setup() {
            super.setup()
            
            selectionStyle = .none
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(hStack)
            hStack.pin(to: contentView.safeAreaLayoutGuide, anchors: [.leading(16), .trailing(-16), .top(4), .bottom(-4)])
            avatarView.resize(anchors: [.width(40), .height(40)])
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.cellBackgroundColor
            nameLabel.font = appearance.nameFont
            nameLabel.textColor = appearance.nameColor
            dateTimeLabel.font = appearance.dateTimeFont
            dateTimeLabel.textColor = appearance.dateTimeColor
        }
        
        override open func prepareForReuse() {
            super.prepareForReuse()
            
            imageTask?.cancel()
            textLabel?.text = nil
            dateTimeLabel.text = nil
        }
        
        open var contentInsets: UIEdgeInsets = .zero {
            didSet {
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
        
        open override var safeAreaInsets: UIEdgeInsets {
            var safeAreaInsets = super.safeAreaInsets
            safeAreaInsets.left += contentInsets.left
            safeAreaInsets.right += contentInsets.right
            safeAreaInsets.top += contentInsets.top
            safeAreaInsets.bottom += contentInsets.bottom
            return safeAreaInsets
        }
    }
}
