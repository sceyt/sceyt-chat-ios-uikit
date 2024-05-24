//
//  NoDataView.swift
//  SceytChatUIKit
//
//  Created by Duc on 19/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class NoDataView: View {
    open lazy var iconView = UIImageView().withoutAutoresizingMask
    open lazy var titleLabel = UILabel().withoutAutoresizingMask
    open lazy var messageLabel = UILabel().withoutAutoresizingMask
    open lazy var vStack = UIStackView(column: [iconView, titleLabel, messageLabel], alignment: .center)
        .withoutAutoresizingMask
    
    open lazy var icon: UIImage? = Images.noResultsSearch {
        didSet {
            iconView.isHidden = icon == nil
            iconView.image = icon
        }
    }
    
    open lazy var title: String? = L10n.Search.NoResults.title {
        didSet {
            titleLabel.isHidden = title == nil
            titleLabel.text = title
        }
    }
    
    open lazy var message: String? = L10n.Search.NoResults.message {
        didSet {
            messageLabel.isHidden = message == nil
            messageLabel.text = message
        }
    }
    
    open override func setup() {
        super.setup()
        
        vStack.setCustomSpacing(12, after: iconView)
        vStack.setCustomSpacing(8, after: titleLabel)
        
        iconView.image = icon
        titleLabel.text = title
        titleLabel.numberOfLines = 0
        messageLabel.text = message
        messageLabel.numberOfLines = 0
    }
    
    open override func setupLayout() {
        super.setupLayout()
        
        addSubview(vStack)
        vStack.pin(to: self, anchors: [.centerX, .centerY, .leading(16, .greaterThanOrEqual), .top(16, .greaterThanOrEqual)])
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = .clear
        titleLabel.font = appearance.titleLabelFont
        messageLabel.font = appearance.messageLabelFont
        titleLabel.textColor = appearance.titleLabelColor
        messageLabel.textColor = appearance.messageLabelColor
    }
}
