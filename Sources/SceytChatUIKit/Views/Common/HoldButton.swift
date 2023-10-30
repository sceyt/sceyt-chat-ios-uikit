//
//  HoldButton.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class HoldButton: Control {
    
    public lazy var appearance = HoldButton.appearance {
        didSet {
            setupAppearance()
        }
    }

   open lazy var imageView = UIImageView()
        .contentMode(.center)
        .withoutAutoresizingMask
    
    open lazy var titleLabel = UILabel()
        .withoutAutoresizingMask
    
    public required init(
        image: UIImage? = nil,
        title: String? = nil,
        tag: Int = 0
    ) {
        super.init(frame: .zero)
        self.tag = tag
        if let image {
            imageView.image = image
        }
        if let title {
            titleLabel.text = title
        }
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        
        backgroundColor = appearance.backgroundColor
        titleLabel.textColor = appearance.titleColor
        titleLabel.font = appearance.titleFont
    }
    
    open override func setup() {
        super.setup()
        imageView.backgroundColor = .clear
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        clipsToBounds = true
        layer.cornerRadius = Layouts.cornerRadius
    }
    
    open override func setupLayout() {
        super.setupLayout()
        addSubview(imageView)
        addSubview(titleLabel)
        
        titleLabel.bottomAnchor.pin(to: bottomAnchor, constant: -8)
        titleLabel.pin(to: self, anchors: [.leading(8), .trailing(-8)])
        imageView.topAnchor.pin(greaterThanOrEqualTo: topAnchor, constant: 8)
        imageView.bottomAnchor.pin(to: titleLabel.topAnchor)
        imageView.centerXAnchor.pin(to: centerXAnchor)
    }
    
    open override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? appearance.highlightedBackgroundColor : appearance.backgroundColor
        }
    }
    
}

public extension HoldButton {
    enum Layouts {
        public static var cornerRadius: CGFloat = 10
    }
}
