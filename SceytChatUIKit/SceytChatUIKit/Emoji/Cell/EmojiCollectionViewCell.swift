//
//  EmojiCollectionViewCell.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

open class EmojiCollectionViewCell: CollectionViewCell {

    open lazy var label = UILabel()
        .withoutAutoresizingMask

    open override func setupAppearance() {
        super.setupAppearance()
        label.font = Fonts.regular.withSize(32)
        label.textAlignment = .center
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(label)
        label.pin(to: contentView)
    }
}
