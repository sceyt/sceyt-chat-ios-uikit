//
//  MessageCell+ForwardView.swift
//  SceytChatUIKit
//

import UIKit

extension MessageCell {
    
    open class ForwardView: View {
        
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
            stackView.spacing = 4
            
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
    }
}
