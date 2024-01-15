//
//  MessageSectionSeparatorView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol MessageSectionSeparator {
    associatedtype Model = Date
    associatedtype Appearance = MessageCell.Appearance
}

open class MessageSectionSeparatorView: CollectionReusableView, MessageSectionSeparator {
    
    open lazy var titleLabel = ContentInsetLabel
        .init()
        .withoutAutoresizingMask
    
    public lazy var appearance = MessageCell.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        titleLabel.isHidden = true
        backgroundColor = appearance.separatorViewBackgroundColor
        titleLabel.backgroundColor = appearance.separatorViewTextBackgroundColor
        titleLabel.font = appearance.separatorViewFont
        titleLabel.textAlignment = .center
        titleLabel.textColor = appearance.separatorViewTextColor
        titleLabel.clipsToBounds = true
        titleLabel.layer.borderWidth = 1
        titleLabel.layer.borderColor = appearance.separatorViewTextBorderColor?.cgColor
        titleLabel.layer.cornerRadius = 10
    }
    
    open override func setupLayout() {
        super.setupLayout()
        addSubview(titleLabel)
        titleLabel.pin(to: self, anchors: [
                .top(8),
                .bottom(-8),
                .centerX(),
                .centerY()]
        )
    }
    
    open var date: String? {
        didSet {
            if let date = date {
                titleLabel.edgeInsets = .init(top: 4, left: 12, bottom: 4, right: 12)
                titleLabel.text = date
                titleLabel.isHidden = false
            } else {
                titleLabel.edgeInsets = .zero
                titleLabel.text = nil
                titleLabel.isHidden = true
            }
        }
    }
    
    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
    }
    
    open class func measure(model: Date, appearance: MessageCell.Appearance) -> CGSize {
        return CGSize(width: 300, height: 40)
    }
}
