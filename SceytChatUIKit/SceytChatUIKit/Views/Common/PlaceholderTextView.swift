//
//  PlaceholderTextView.swift
//  SceytChatUIKit
//

import UIKit

open class PlaceholderTextView: TextView {

    open var onUpdate: (() -> Void)?
    
    open lazy var placeholderLabel = UILabel()
        .withoutAutoresizingMask
    
    override open  func setup() {
        super.setup()
        NotificationCenter.default.addObserver(forName: UITextView.textDidChangeNotification,
                                               object: self,
                                               queue: .main) {[weak self] _ in
            guard let self = self else { return }
            self.placeholderLabel.isHidden = !self.text.isEmpty
        }
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
    
    override open func setupLayout() {
        super.setupLayout()
        addSubview(placeholderLabel)
        placeholderLabel.leadingAnchor.pin(to: leadingAnchor, constant: directionalLayoutMargins.leading + textContainerInset.left)
        placeholderLabel.trailingAnchor.pin(to: trailingAnchor, constant: -directionalLayoutMargins.trailing - textContainerInset.right)
        placeholderLabel.topAnchor.pin(to: topAnchor, constant: directionalLayoutMargins.top)
    }
    
    override open var text: String! {
        didSet {
            placeholderLabel.isHidden = !text.isEmpty
        }
    }
    
    override open var attributedText: NSAttributedString! {
        didSet {
            placeholderLabel.isHidden = !attributedText.isEmpty
        }
    }
}
