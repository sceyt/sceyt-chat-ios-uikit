//
//  ChannelInfoViewController+DescriptionCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension ChannelInfoViewController {
    open class DescriptionCell: TableViewCell {
        open lazy var label = UILabel()
            .withoutAutoresizingMask
        
        open lazy var textView = UITextView()
            .withoutAutoresizingMask
        
        override open func setup() {
            super.setup()
            
            textView.isEditable = false
            textView.isSelectable = false
            textView.isScrollEnabled = false
            textView.textContainer.lineFragmentPadding = 0
            textView.textContainerInset = .zero
        }
        
        override open func setupAppearance() {
            super.setupAppearance()
            
            backgroundColor = appearance.backgroundColor
            label.text = appearance.titleText
            label.font = appearance.titleLabelAppearance.font
            label.textColor = appearance.titleLabelAppearance.foregroundColor
            textView.backgroundColor = .clear
            textView.textColor = appearance.descriptionLabelAppearance.foregroundColor
            textView.font = appearance.descriptionLabelAppearance.font
        }
        
        override open func setupLayout() {
            super.setupLayout()
            
            contentView.addSubview(label)
            contentView.addSubview(textView)
            label.pin(to: contentView, anchors: [.leading, .trailing, .top(9)])
            textView.pin(to: contentView, anchors: [.leading, .trailing, .bottom(-9)])
            textView.topAnchor.pin(to: label.bottomAnchor)
        }
        
        open var data: String? {
            didSet {
                textView.text = data
            }
        }
        
        open override var safeAreaInsets: UIEdgeInsets {
            .init(top: 0, left: 2 * Components.channelInfoViewController.Layouts.cellHorizontalPadding,
                  bottom: 0, right: 2 * Components.channelInfoViewController.Layouts.cellHorizontalPadding)
        }
    }
}
