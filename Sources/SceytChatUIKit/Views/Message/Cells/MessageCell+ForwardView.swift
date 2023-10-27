//
//  MessageCell+ForwardView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension MessageCell {
    
    open class ForwardView: View, MessageCellMeasurable {
     
        open lazy var iconView = UIImageView()
            .withoutAutoresizingMask
        
        open lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
        
        open lazy var stackView = UIStackView()
            .withoutAutoresizingMask
        
        public lazy var appearance = MessageCell.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open override func setup() {
            super.setup()
            stackView.isUserInteractionEnabled = false
            stackView.alignment = .leading
            stackView.axis = .horizontal
            stackView.spacing = Measure.itemSpacing
            
            iconView.image = Images.forwardedMessage
            titleLabel.text = L10n.Message.Forward.title
        }
       
        open override func setupLayout() {
            super.setupLayout()
            addSubview(stackView)
            stackView.addArrangedSubview(iconView)
            stackView.addArrangedSubview(titleLabel)
            stackView.pin(to: self)
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            titleLabel.font = appearance.forwardTitleFont
            titleLabel.textColor = appearance.forwardTitleColor

        }
        
        open class func measure(
            model: MessageLayoutModel,
            appearance: MessageCell.Appearance
        ) -> CGSize {
            let iconSize = Images.forwardedMessage.size
            let text = NSAttributedString(string: L10n.Message.Forward.title, attributes: [.font: appearance.forwardTitleFont as Any])
            let textSize = TextSizeMeasure.calculateSize(of: text)
            return CGSize(width: iconSize.width + textSize.textSize.width + Measure.itemSpacing, height: max(iconSize.height, textSize.textSize.height))
        }
    }
}

public extension MessageCell.ForwardView {
    enum Anchors {
        public static var top = CGFloat(8)
        public static var leading = CGFloat(12)
        public static var trailing = CGFloat(-12)
        public static var width: CGFloat { Components.messageLayoutModel.defaults.messageWidth - leading + trailing }
    }
    
    enum Measure {
        public static var itemSpacing = CGFloat(4)
    }
}

