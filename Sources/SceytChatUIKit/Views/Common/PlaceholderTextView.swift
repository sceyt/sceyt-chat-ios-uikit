//
//  PlaceholderTextView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import UIKit

open class PlaceholderTextView: TextView {
    @Published public var event: Event?

    open lazy var placeholderLabel = UILabel()
        .withoutAutoresizingMask
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override open func setup() {
        super.setup()
        
        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: self,
            queue: .main)
        { [weak self] _ in
            self?.textDidChange()
        }
        directionalLayoutMargins = .zero
    }
    
    open var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
        }
    }
    
    open var placeholderColor: UIColor? {
        didSet {
            placeholderLabel.textColor = placeholderColor
        }
    }
    
    open var attributedPlaceholder: NSAttributedString? {
        didSet {
            placeholderLabel.attributedText = attributedPlaceholder
        }
    }
    
    override open var textAlignment: NSTextAlignment {
        didSet {
            placeholderLabel.textAlignment = textAlignment
        }
    }
    
    override open var font: UIFont? {
        didSet {
            placeholderLabel.font = font
        }
    }
    
    override open var text: String! {
        didSet {
            placeholderLabel.isHidden = !text.isEmpty
            event = .textChanged
        }
    }
    
    override open var attributedText: NSAttributedString! {
        didSet {
            placeholderLabel.isHidden = !attributedText.isEmpty
            event = .textChanged
        }
    }
    
    override open var textContainerInset: UIEdgeInsets {
        didSet {
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    override open var contentSize: CGSize {
        didSet {
            if oldValue != contentSize {
                event = .contentSizeUpdate(old: oldValue.height, new: contentSize.height)
            }
        }
    }
    
    override open func setupLayout() {
        super.setupLayout()
        addSubview(placeholderLabel)
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        placeholderLabel.frame.size = placeholderLabel.sizeThatFits(CGSize(
            width: frame.width - directionalLayoutMargins.leading - textContainerInset.left - directionalLayoutMargins.trailing - textContainerInset.right,
            height: .greatestFiniteMagnitude))
        placeholderLabel.frame.origin.y = directionalLayoutMargins.top + textContainerInset.top
        
        if textAlignment == .right {
            placeholderLabel.right = frame.width - directionalLayoutMargins.trailing - textContainerInset.right - textContainer.lineFragmentPadding
        } else {
            placeholderLabel.left = directionalLayoutMargins.leading + textContainerInset.left + textContainer.lineFragmentPadding
        }
    }
    
    @objc open func textDidChange() {
        placeholderLabel.isHidden = !text.isEmpty
        event = .textChanged
    }
}

public extension PlaceholderTextView {
    enum Event {
        case textChanged
        case pastedImage
        case contentSizeUpdate(old: CGFloat, new: CGFloat)
    }
}
