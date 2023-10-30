//
//  ComposerVC+InputTextView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine
import CoreServices

extension ComposerVC {
    open class InputTextView: PlaceholderTextView {
        open private(set) var typingTimer: Timer?
        
        open var formatEvent = PassthroughSubject<FormatEvent, Never>()
        open var typingEvent = PassthroughSubject<Bool, Never>()

        open func _setCGColors() {
            layer.borderColor = appearance.borderColor?.cgColor
        }
        
        open override func setup() {
            super.setup()
            textContainerInset = .init(top: 8, left: 12, bottom: 8, right: 12)
            placeholder = L10n.Message.Input.placeholder
            layer.borderWidth = 0.5
            layer.cornerRadius = 16
            allowsEditingTextAttributes = true
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            font = appearance.textFont
            textColor = appearance.textColor
            placeholderColor = appearance.placeholderColor
            backgroundColor = appearance.backgroundColor
            _setCGColors()
        }
        
        open func startTypingTimer() {
            if typingTimer?.isValid == true {
                typingTimer?.invalidate()
            }
            typingEvent.send(true)
            typingTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] (_) in
                self?.typingEvent.send(false)
            }
        }
        
        open override var text: String! {
            didSet {
                resetTypingAttributes()
            }
        }
        
        open override var attributedText: NSAttributedString! {
            didSet {
                resetTypingAttributes()
            }
        }
        
        open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            _setCGColors()
        }
        
        open override func textDidChange() {
            startTypingTimer()
            super.textDidChange()
        }
        
        open override func paste(_ sender: Any?) {
            var pastedAttributedString: NSAttributedString?
            let pasteboard = UIPasteboard.general
            if let data = pasteboard.data(forPasteboardType: kUTTypeRTF as String) {
                pastedAttributedString = try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            } else if let data = pasteboard.data(forPasteboardType: "com.apple.flat-rtfd") {
                pastedAttributedString = try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
            }
            
            guard let pastedAttributedString
            else { 
                super.paste(sender)
                return
            }
            
            let mPastedAttributedString = NSMutableAttributedString(string: pastedAttributedString.string)
            pastedAttributedString.enumerateAttributes(in: .init(location: 0, length: pastedAttributedString.length)) { value, range, pointer in
                if let font = value[.font] as? UIFont {
                    var newFont = InputTextView.appearance.textFont
                    if font.isBold {
                        newFont = Formatters.font.toBold(newFont)
                    }
                    if font.isItalic {
                        newFont = Formatters.font.toItalic(newFont)
                    }
                    if font.isMonospace {
                        newFont = Formatters.font.toMonospace(newFont)
                    }
                    mPastedAttributedString.addAttribute(.font, value: newFont, range: range)
                }
                if let _ = value[.strikethroughStyle] {
                    mPastedAttributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
                if let _ = value[.underlineStyle] {
                    mPastedAttributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
            }
            mPastedAttributedString.addAttribute(.foregroundColor,
                                                 value: appearance.textColor as Any,
                                                 range: .init(location: 0, length: mPastedAttributedString.length))
            let mAttributedText = attributedText.mutableCopy() as! NSMutableAttributedString
            let range = selectedRange
            mAttributedText.safeReplaceCharacters(in: range, with: mPastedAttributedString)
            attributedText = mAttributedText
            selectedRange = .init(location: range.location + mPastedAttributedString.length, length: 0)
        }
        
        open func resetTypingAttributes() {
            typingAttributes[.font] = appearance.textFont
            typingAttributes[.foregroundColor] = appearance.textColor
            typingAttributes[.underlineStyle] = nil
            typingAttributes[.strikethroughStyle] = nil
        }
        
        open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            let menuItemsCount = UIMenuController.shared.menuItems?.count ?? 0
            if menuItemsCount > 1 {
                return action == #selector(toggleBoldface)
                || action == #selector(toggleItalics)
                || action == #selector(toggleMonospace)
                || action == #selector(toggleStrikethrough)
                || action == #selector(toggleUnderline)
            } else if action == NSSelectorFromString("_showTextStyleOptions:") {
                return true
            }
            return super.canPerformAction(action, withSender: sender)
        }
        
        open var selectedRect: CGRect {
            if let selectedTextRange {
                return firstRect(for: selectedTextRange)
            } else {
                return bounds
            }
        }
        
        @objc func _showTextStyleOptions(_ sender: Any) {
            UIMenuController.shared.menuItems = [
                UIMenuItem(title: AttributeType.bold.string, action: #selector(toggleBoldface)),
                UIMenuItem(title: AttributeType.italic.string, action: #selector(toggleItalics)),
                UIMenuItem(title: AttributeType.monospace.string, action: #selector(toggleMonospace)),
                UIMenuItem(title: AttributeType.strikethrough.string, action: #selector(toggleStrikethrough)),
                UIMenuItem(title: AttributeType.underline.string, action: #selector(toggleUnderline)),
            ]
            UIMenuController.shared.showMenu(from: self, rect: selectedRect.offsetBy(dx: 0.0, dy: -contentOffset.y).insetBy(dx: 0.0, dy: -2.0))
            UIMenuController.shared.menuItems = []
        }
        
        func hideMenu() {
            UIMenuController.shared.menuItems = []
            UIMenuController.shared.hideMenu()
        }
        
        open override func toggleBoldface(_ sender: Any?) {
            hideMenu()
            formatEvent.send(.bold)
        }
        
        open override func toggleItalics(_ sender: Any?) {
            hideMenu()
            formatEvent.send(.italic)
        }
        
        @objc func toggleMonospace(_ sender: Any?) {
            hideMenu()
            formatEvent.send(.monospace)
        }
        
        @objc func toggleStrikethrough(_ sender: Any?) {
            hideMenu()
            formatEvent.send(.strikethrough)
        }
        
        open override func toggleUnderline(_ sender: Any?) {
            hideMenu()
            formatEvent.send(.underline)
        }
    }
}

public extension ComposerVC.InputTextView {
    enum FormatEvent {
        case bold, italic, monospace, strikethrough, underline
    }
}
