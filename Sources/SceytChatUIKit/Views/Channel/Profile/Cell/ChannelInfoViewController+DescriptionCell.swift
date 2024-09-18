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
        
        public lazy var appearance = Components.channelInfoViewController.appearance {
            didSet {
                setupAppearance()
            }
        }
        
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
            
            backgroundColor = appearance.cellBackgroundColor
            label.text = L10n.Channel.Profile.about
            label.font = appearance.descriptionLabelFont
            label.textColor = appearance.descriptionLabelColor
            textView.backgroundColor = .clear
            textView.textColor = appearance.descriptionColor
            textView.font = appearance.descriptionFont
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
