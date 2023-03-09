//
//  ChannelVC+BlockView.swift
//  SceytChatUIKit
//

import UIKit

extension ChannelVC {
    
    open class BlockView: View {
        
        lazy var iconView = UIImageView()
            .contentMode(.center)
            .withoutAutoresizingMask
        
        lazy var titleLabel = UILabel()
            .withoutAutoresizingMask
            .contentHuggingPriorityH(.required)
        
        lazy var stackView: UIStackView = {
            $0.axis = .horizontal
            $0.distribution = .fillProportionally
            $0.alignment = .center
            $0.spacing = 10
            return $0.withoutAutoresizingMask
        }(UIStackView(arrangedSubviews: [iconView, titleLabel]))
        
        lazy var borderView = UIView()
            .withoutAutoresizingMask
        
        open override func setup() {
            super.setup()
            iconView.image = .warning
            titleLabel.text = L10n.Channel.Peer.blocked
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            backgroundColor = appearance.backgroundColor
            titleLabel.font = appearance.titleFont
            titleLabel.textColor = appearance.titleColor
            borderView.backgroundColor = appearance.borderColor
        }
        
        open override func setupLayout() {
            super.setupLayout()
            addSubview(stackView)
            addSubview(borderView)
            stackView.pin(to: self, anchors: [.top(), .bottom(), .leading(0, .greaterThanOrEqual), .trailing(0, .lessThanOrEqual), .centerX()])
            titleLabel.heightAnchor.pin(to: stackView.heightAnchor)
            borderView.pin(to: self, anchors: [.top(), .trailing(), .leading()])
            borderView.heightAnchor.pin(constant: 1)
        }
    }
}
