//
//  MessageCell+InfoView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell {
    open class InfoView: View, MessageCellMeasurable {
        open lazy var eyeView = UIImageView()
            .contentMode(.center)
            .contentHuggingPriorityH(.required)
        
        open lazy var displayedLabel = UILabel()
            .contentHuggingPriorityH(.required)
        
        open lazy var stateLabel = UILabel()
            .contentHuggingPriorityH(.required)
        
        open lazy var dateLabel = UILabel()
            .contentHuggingPriorityH(.required)

        open lazy var tickView = UIImageView()
            .contentMode(.center)
            .contentHuggingPriorityH(.required)
        
        open lazy var hStack = UIStackView(
            row: [eyeView, displayedLabel, stateLabel, dateLabel, tickView],
            spacing: 4,
            alignment: .center)
            .withoutAutoresizingMask

        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open var hasBackground: Bool {
            !data.attachments.isEmpty
                && !data.hasFileAttachments
                && !data.hasVoiceAttachments
        }
        
        override open func setup() {
            super.setup()
            
            eyeView.image = Images.eye.withRenderingMode(.alwaysTemplate)
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            stateLabel.font = appearance.infoViewStateFont
            stateLabel.textColor = appearance.infoViewStateTextColor
            dateLabel.font = appearance.infoViewDateFont
            dateLabel.textColor = appearance.infoViewDateTextColor
            eyeView.tintColor = dateLabel.textColor
            displayedLabel.font = dateLabel.font
            displayedLabel.textColor = dateLabel.textColor
        }

        override open func setupLayout() {
            super.setupLayout()
            addSubview(hStack)
            displayedLabel.textAlignment = .right
            dateLabel.textAlignment = .right
            stateLabel.textAlignment = .right
            hStack.pin(to: self, anchors: [.top, .bottom, .trailing, .leading(0, .greaterThanOrEqual)])
        }
        
        open var data: MessageLayoutModel! {
            didSet {
                guard let data else { return }
                let message = data.message
                if message.state != .deleted {
                    if data.channel.channelType == .broadcast {
                        eyeView.isHidden = false
                        displayedLabel.isHidden = false
                        displayedLabel.text = "\(SceytChatUIKit.shared.formatters.messageViewCountFormatter.format(UInt64(message.markerCount?[DefaultMarker.displayed.rawValue] ?? 0))) •"
                        tickView.isHidden = true
                    } else if !message.incoming {
                        eyeView.isHidden = true
                        displayedLabel.isHidden = true
                        tickView.isHidden = false
                    } else {
                        eyeView.isHidden = true
                        displayedLabel.isHidden = true
                        tickView.isHidden = true
                    }
                } else {
                    eyeView.isHidden = true
                    displayedLabel.isHidden = true
                    tickView.isHidden = true
                }
                dateLabel.text = SceytChatUIKit.shared.formatters.messageDateFormatter.format(message.createdAt)
                if message.state == .edited {
                    stateLabel.isHidden = false
                    stateLabel.text = L10n.Message.Info.edited
                    stateLabel.textColor = hasBackground ? appearance.infoViewStateWithBackgroundTextColor : appearance.infoViewStateTextColor
                } else {
                    stateLabel.isHidden = true
                    stateLabel.text = nil
                }
            }
        }
        
        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            measure(channel: model.channel, message: model.message, appearance: appearance)
        }
        
        open class func measure(
            channel: ChatChannel,
            message: ChatMessage,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            var config = TextSizeMeasure.Config()
            config.maximumNumberOfLines = 1
            config.lastFragmentUsedRect = false
            config.font = appearance.infoViewDateFont
            
            let createdAt = SceytChatUIKit.shared.formatters.messageDateFormatter.format(message.createdAt)
            var size = TextSizeMeasure.calculateSize(of: createdAt, config: config).textSize
            size.width += 4
            
            if message.state != .deleted {
                if channel.channelType == .broadcast {
                    let displayed = "\(SceytChatUIKit.shared.formatters.messageViewCountFormatter.format(UInt64(message.markerCount?[DefaultMarker.displayed.rawValue] ?? 0))) •"
                    let displayedSize = TextSizeMeasure.calculateSize(of: displayed, config: config).textSize
                    size.width += 4 + displayedSize.width
                    size.height = max(size.height, displayedSize.height)
                    let eyeSize = Images.eye.size
                    size.width += 4 + eyeSize.width
                    size.height = max(size.height, eyeSize.height)
                } else {
                    let tickViewSize = Images.sentMessage.size
                    if !message.incoming {
                        size.width += 4 + tickViewSize.width
                    }
                    size.height = max(size.height, tickViewSize.height)
                }
            }
            
            if message.state == .edited {
                config.font = appearance.infoViewStateFont
                let stateLabelText = L10n.Message.Info.edited
                let stateLabelSize = TextSizeMeasure.calculateSize(of: stateLabelText, config: config).textSize
                size.width += 4 + stateLabelSize.width
                size.height = max(size.height, stateLabelSize.height)
            }
            
            return size
        }
    }
}
