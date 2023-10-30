//
//  ContentInsetLabel.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 20.09.22.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class ContentInsetLabel: UILabel {

    open var edgeInsets: UIEdgeInsets = .zero {
        didSet {
            setNeedsDisplay()
        }
    }

    open override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: edgeInsets))
    }

    open override var intrinsicContentSize: CGSize {
        return addInsets(to: super.intrinsicContentSize)
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return addInsets(to: super.sizeThatFits(size))
    }

    open func addInsets(to size: CGSize) -> CGSize {
        let width = size.width + edgeInsets.left + edgeInsets.right
        let height = size.height + edgeInsets.top + edgeInsets.bottom
        return CGSize(width: width, height: height)
    }
    
    open override var bounds: CGRect {
        didSet {
            // ensures this works within stack views if multi-line
            preferredMaxLayoutWidth = bounds.width - (edgeInsets.left + edgeInsets.right)
        }
    }

}
