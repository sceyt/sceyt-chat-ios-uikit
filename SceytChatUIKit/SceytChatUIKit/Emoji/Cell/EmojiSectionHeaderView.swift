//
//  EmojiSectionHeaderView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

open class EmojiSectionHeaderView: CollectionReusableView, Bindable {

    private var isConfigured = false

    open lazy var label = UILabel()
        .withoutAutoresizingMask

    open override func setup() {
        super.setup()
    }

    open override func setupLayout() {
        super.setupLayout()
        addSubview(label)
        label.pin(to: self, anchors: [.top(), .leading(8), .trailing(), .bottom()])
    }

    open override func setupAppearance() {
        super.setupAppearance()
        label.textColor = Appearance.Colors.textBlack
        label.font = Fonts.regular.withSize(14)
    }

    open func bind(_ data: String?) {
        label.text = data
    }
}
