//
//  ChannelProfileDescriptionCell.swift
//  SceytChatUIKit
//

import UIKit

open class ChannelProfileDescriptionCell: TableViewCell {

    open lazy var textView = UITextView()
        .withoutAutoresizingMask
    
    public lazy var appearance = ChannelProfileVC.appearance {
        didSet {
            setupAppearance()
        }
    }
    
    open override func setup() {
        super.setup()
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        textView.textColor = appearance.descriptionColor
        textView.font = appearance.descriptionFont
    }
    
    open override func setupLayout() {
        super.setupLayout()
        contentView.addSubview(textView)
        textView.pin(to: contentView, anchors: [.leading(16),
                                                .top(14),
                                                .trailing(0, .lessThanOrEqual),
                                                .bottom(-14),
                                             .centerY])
    }
    
    open var data: String? {
        didSet {
            textView.text = data
        }
    }

    open override var safeAreaInsets: UIEdgeInsets {
        .init(top: 0, left: 16, bottom: 0, right: 16)
    }
}
