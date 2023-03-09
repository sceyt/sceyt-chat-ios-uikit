//
//  ChannelProfileEditFieldCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileEditFieldCell: TableViewCell {

    open lazy var textView = UITextView()
        .withoutAutoresizingMask
    
    open lazy var separatorView = UIView()
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelProfileEditVC.appearance {
        didSet {
            setupAppearance()
        }
    }

    open override func setup() {
        super.setup()
        textView.isScrollEnabled = false
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        textView.backgroundColor = .clear
        textView.textColor = appearance.textFieldColor
        textView.font = appearance.textFieldFont
        separatorView.backgroundColor = appearance.separatorColor
    }

    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(textView)
        contentView.addSubview(separatorView)
        textView.pin(to: contentView, anchors: [.leading(16), .top, .trailing(-16), .bottom])
        separatorView.pin(to: contentView, anchors: [.bottom(), .trailing()])
        separatorView.leadingAnchor.pin(to: textView.leadingAnchor)
        separatorView.heightAnchor.pin(constant: 1)
        contentView.heightAnchor.pin(greaterThanOrEqualToConstant: 52)
    }

}
