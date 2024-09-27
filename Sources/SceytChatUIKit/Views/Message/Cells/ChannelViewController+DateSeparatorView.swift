//
//  ChannelViewController+DateSeparatorView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol ChannelDateSeparator {
    associatedtype Model = Date
    associatedtype Appearance = MessageCell.Appearance
}

extension ChannelViewController {
    open class DateSeparatorView: CollectionReusableView, ChannelDateSeparator {
        
        open lazy var titleLabel = ContentInsetLabel
            .init()
            .withoutAutoresizingMask
        
        open override func setupAppearance() {
            super.setupAppearance()
            titleLabel.isHidden = true
            backgroundColor = appearance.backgroundColor
            titleLabel.backgroundColor = appearance.labelAppearance.backgroundColor
            titleLabel.font = appearance.labelAppearance.font
            titleLabel.textAlignment = .center
            titleLabel.textColor = appearance.labelAppearance.foregroundColor
            titleLabel.clipsToBounds = true
            titleLabel.layer.borderWidth = 1
            titleLabel.layer.borderColor = appearance.labelBorderColor
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
}
