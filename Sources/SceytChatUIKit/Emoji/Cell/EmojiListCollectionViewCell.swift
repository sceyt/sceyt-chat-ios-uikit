//
//  EmojiCollectionViewCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

open class EmojiListCollectionViewCell: CollectionViewCell {
    open lazy var label = UILabel()
        .withoutAutoresizingMask

    override open func setup() {
        super.setup()

        layer.masksToBounds = true
    }

    override open func setupAppearance() {
        super.setupAppearance()
        label.font = Fonts.regular.withSize(24)
        label.textAlignment = .center
    }

    override open func setupLayout() {
        super.setupLayout()
        contentView.addSubview(label)
        label.pin(to: contentView)
    }

    override open var isSelected: Bool {
        didSet {
            alpha = (isSelected || isHighlighted) ? 0.5 : 1
        }
    }

    override open var isHighlighted: Bool {
        didSet {
            alpha = (isSelected || isHighlighted) ? 0.5 : 1
        }
    }
}
