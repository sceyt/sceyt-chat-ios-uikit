//
//  TimeLabel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class TimeLabel: View {
    
    open lazy var iconView = UIImageView()
        .withoutAutoresizingMask
    
    open lazy var textLabel = UILabel()
        .withoutAutoresizingMask
    
    open lazy var stackView = UIStackView(arrangedSubviews: [iconView, textLabel])
        .withoutAutoresizingMask
    
    open override func setup() {
        super.setup()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillProportionally
        stackView.spacing = 4
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        textLabel.font = Fonts.regular.withSize(12)
    }
    
    open override func setupLayout() {
        super.setupLayout()
        addSubview(stackView)
        stackView.pin(to: self, anchors: [.leading(6), .trailing(-6), .top(3), .bottom(-3)])
    }
    
    var text: String? {
        set { textLabel.text = newValue }
        get { textLabel.text }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}
