//
//  ComposerVC+InputTextView.swift
//  SceytChatUIKit
//  Copyright © 2021 Varmtech LLC. All rights reserved.
//

import UIKit

extension ComposerVC {
    
    open class InputTextView: TextView {
        
        @Published public var event: Event?
        
        open lazy var placeholderLabel = UILabel()
            .withoutAutoresizingMask
        
        open var onTyping: ((Bool) -> Void)?
        open private(set) var typingTimer: Timer?
        
        open func _setCGColors() {
            layer.borderColor = appearance.borderColor?.cgColor
        }
        
        open override func setup() {
            super.setup()
            textContainerInset = .init(top: 8, left: 12, bottom: 8, right: 12)
            NotificationCenter.default.addObserver(forName: UITextView.textDidChangeNotification,
                                                   object: self,
                                                   queue: .main) {[weak self] _ in
                guard let self = self else { return }
                self.placeholderLabel.isHidden = !self.text.isEmpty
                self.setTimer()
                self.event = .update
            }
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            font = appearance.textFont?.withSize(16)
            backgroundColor = appearance.backgroundColor
            _setCGColors()
            layer.borderWidth = 0.5
            layer.cornerRadius = 16
            textColor = .textBlack
            placeholderLabel.text = L10n.Message.Input.placeholder
            placeholderLabel.textAlignment = .left
            placeholderLabel.font = font
            placeholderLabel.textColor = appearance.placeholderColor
        }
        
        open override func setupLayout() {
            super.setupLayout()
            addSubview(placeholderLabel)
            placeholderLabel.leadingAnchor.pin(to: leadingAnchor, constant: directionalLayoutMargins.leading + textContainerInset.left)
            placeholderLabel.trailingAnchor.pin(to: trailingAnchor, constant: -directionalLayoutMargins.trailing - textContainerInset.right)
            placeholderLabel.centerYAnchor.pin(to: centerYAnchor)
        }
        
        open func setTimer() {
            if typingTimer?.isValid == true {
                typingTimer?.invalidate()
            }
            onTyping?(true)
            typingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] (_) in
                self?.onTyping?(false)
            }
        }
        
        open override var text: String! {
            didSet {
                placeholderLabel.isHidden = !text.isEmpty
                event = .update
            }
        }
        
        open override var attributedText: NSAttributedString! {
            didSet {
                placeholderLabel.isHidden = !attributedText.isEmpty
                event = .update
            }
        }
        
        open override var contentSize: CGSize {
            didSet {
                if oldValue != contentSize {
                    event = .contentSizeUpdate(old: oldValue.height, new: contentSize.height)
                }
            }
        }
        
        open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            _setCGColors()
        }
        
        open override func paste(_ sender: Any?) {
            super.paste(sender)
            event = .paste
        }
    }
}

extension ComposerVC.InputTextView {
    
    public enum Event {
        case update
        case paste
        case contentSizeUpdate(old: CGFloat, new: CGFloat)
    }
}
