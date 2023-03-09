//
//  ContentInsetLabel.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
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

}
