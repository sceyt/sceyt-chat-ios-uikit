//
//  SeparatorHeaderView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class SeparatorHeaderView: TableViewHeaderFooterView {
    open lazy var titleLabel = UILabel().withoutAutoresizingMask

    override open func setupLayout() {
        super.setupLayout()

        contentView.addSubview(titleLabel)
        titleLabel.heightAnchor.pin(constant: Layouts.height)
        titleLabel.pin(to: contentView, anchors: [.leading(Layouts.horizontalPadding), .trailing(-Layouts.horizontalPadding), .centerY()])
    }

    override open func setupAppearance() {
        super.setupAppearance()

        titleLabel.text = appearance.title
        contentView.backgroundColor = appearance.backgroundColor
        titleLabel.textColor = appearance.labelAppearance.foregroundColor
        titleLabel.font = appearance.labelAppearance.font
        titleLabel.textAlignment = appearance.textAlignment
    }
}

public extension SeparatorHeaderView {
    enum Layouts {
        public static var height: CGFloat = 32
        public static var horizontalPadding: CGFloat = 16
    }
}
