//
//  CircleImageView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class CircleImageView: View {

    open private(set) var imageView = ImageView()
        .withoutAutoresizingMask
        .contentMode(.scaleAspectFill)

    open override var intrinsicContentSize: CGSize {
        imageView.image?.size ?? super.intrinsicContentSize
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 0.5 * min(bounds.width, bounds.height)
    }
    
    override open func setupLayout() {
        super.setupLayout()
        addSubview(imageView)
        imageView.pin(to: self)
    }

    open override func setupAppearance() {
        super.setupAppearance()
        imageView.clipsToBounds = true
        clipsToBounds = true
    }

    open var image: UIImage? {
        set { imageView.image = newValue }
        get { imageView.image }
    }

    open override var contentMode: UIView.ContentMode {
        set { imageView.contentMode = newValue }
        get { imageView.contentMode }
    }
}

