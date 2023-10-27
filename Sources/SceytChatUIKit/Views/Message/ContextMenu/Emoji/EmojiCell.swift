//
//  EmojiCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 16.02.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class EmojiCell: CollectionViewCell {

    open lazy var label = UILabel()
        .withoutAutoresizingMask
    
    open override func setup() {
        label.font = .systemFont(ofSize: 30)
    }
    
    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(label)
        label.pin(to: contentView, anchors: [.centerX, .centerY])
    }

    var data: String! {
        didSet {
            label.text = data
        }
    }
}
