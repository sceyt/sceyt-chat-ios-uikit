//
//  EditChannelVC+TextFieldCell.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelVC {
    open class TextFieldCell: TableViewCell, UITextViewDelegate {
        
        open lazy var textView = PlaceholderTextView()
            .withoutAutoresizingMask
        
        open lazy var separatorView = UIView()
            .withoutAutoresizingMask
        
        open var allowsNewline = true
        
        open var onTextChanged: ((String) -> Void)?
        
        public lazy var appearance = Components.editChannelVC.appearance {
            didSet {
                setupAppearance()
            }
        }
        
        open override func setup() {
            super.setup()
            textView.isScrollEnabled = false
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.delegate = self
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            textView.backgroundColor = .clear
            textView.textColor = appearance.textFieldColor
            textView.font = appearance.textFieldFont
            textView.placeholderColor = appearance.textFieldPlaceholderColor
            
            separatorView.backgroundColor = appearance.separatorColor
            backgroundColor = appearance.textFieldBackgroundColor
        }
        
        open override func setupLayout() {
            super.setupLayout()
            contentView.addSubview(textView)
            contentView.addSubview(separatorView)
            textView.pin(to: contentView, anchors: [.leading(16), .trailing(-16), .top(16), .bottom(-16)])
            separatorView.pin(to: contentView, anchors: [.bottom, .leading, .trailing])
            separatorView.heightAnchor.pin(constant: 1)
            contentView.heightAnchor.pin(greaterThanOrEqualToConstant: 56)
        }
        
        public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text.contains("\n"), !allowsNewline {
                return false
            }
            return true
        }
        public func textViewDidChange(_ textView: UITextView) {
            onTextChanged?(textView.text)
        }
    }
}
