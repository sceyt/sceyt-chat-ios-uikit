//
//  MessageInputViewController+InputTextView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit
import Combine
import CoreServices

extension MessageInputViewController {
    open class InputTextView: PlaceholderTextView {
        open private(set) var typingTimer: Timer?
        
        open var formatEvent = PassthroughSubject<FormatEvent, Never>()
        open var typingEvent = PassthroughSubject<Bool, Never>()

        open func _setCGColors() {
            layer.borderColor = appearance.textInputAppearance.borderColor
        }
        
        deinit {
            typingTimer?.invalidate()
            typingTimer = nil
        }
        
        open override func setup() {
            super.setup()
            textContainerInset = .init(top: 8, left: 12, bottom: 8, right: 12)
            placeholder = appearance.textInputAppearance.placeholder
            layer.borderWidth = appearance.textInputAppearance.borderWidth
            layer.cornerRadius = appearance.textInputAppearance.cornerRadius
            allowsEditingTextAttributes = true
        }
        
        open override func setupAppearance() {
            super.setupAppearance()
            placeholderColor = appearance.textInputAppearance.placeholderAppearance.foregroundColor
            backgroundColor = appearance.textInputAppearance.backgroundColor
            _setCGColors()

            // UITextView.font and UITextView.textColor write to NSTextStorage for the
            // entire string range, overwriting per-character attributes such as mention
            // foreground color and font. Guard against this when the text view already
            // has content (e.g. a restored draft with mentions) so those attributes are
            // preserved. When the text view is empty the setters are safe to call.
            if attributedText == nil || attributedText.length == 0 {
                font = appearance.textInputAppearance.labelAppearance.font
                textColor = appearance.textInputAppearance.labelAppearance.foregroundColor
            } else {
                // Keep placeholderLabel in sync (normally done by the font setter).
                placeholderLabel.font = appearance.textInputAppearance.labelAppearance.font
                // Keep typingAttributes correct so newly typed text has the right style.
                resetTypingAttributes()
            }
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
            var isFromCustomPasteboardType: Bool = false
            
            // First try to get our custom attributed string with all attributes (including .mention)
            if let data = pasteboard.data(forPasteboardType: "com.sceyt.attributedstring"),
               let archived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data) {
                pastedAttributedString = archived
                isFromCustomPasteboardType = true
            } else if let data = pasteboard.data(forPasteboardType: kUTTypeRTF as String) {
                pastedAttributedString = try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            } else if let data = pasteboard.data(forPasteboardType: "com.apple.flat-rtfd") {
                pastedAttributedString = try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
            } else if let data = pasteboard.data(forPasteboardType: "com.apple.flat-rtfd") {
                pastedAttributedString = try? NSAttributedString(data: data, options: [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
            } else if pasteboard.hasImages {
                event = .pastedImage
                return
            } else if let data = pasteboard.data(forPasteboardType: "public.utf8-plain-text") {
                pastedAttributedString = try? NSAttributedString(data: data, options: [:], documentAttributes: nil)
            }
            
            guard let pastedAttributedString
            else { 
                super.paste(sender)
                return
            }
            
            let mPastedAttributedString = isFromCustomPasteboardType ?
            NSMutableAttributedString(attributedString: pastedAttributedString) :
            NSMutableAttributedString(string: pastedAttributedString.string)
            
            if !isFromCustomPasteboardType {
                pastedAttributedString.enumerateAttributes(in: .init(location: 0, length: pastedAttributedString.length)) { value, range, pointer in
                    if let font = value[.font] as? UIFont {
                        var newFont = appearance.textInputAppearance.labelAppearance.font
                        if font.isBold {
                            newFont = newFont.toBold
                        }
                        if font.isItalic {
                            newFont = newFont.toItalic
                        }
                        if font.isMonospace {
                            newFont = newFont.toMonospace
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
                                                     value: appearance.textInputAppearance.labelAppearance.foregroundColor,
                                                     range: .init(location: 0, length: mPastedAttributedString.length))
            }
            let mAttributedText = attributedText.mutableCopy() as! NSMutableAttributedString
            let range = selectedRange
            mAttributedText.safeReplaceCharacters(in: range, with: mPastedAttributedString)
            attributedText = mAttributedText
            selectedRange = .init(location: range.location + mPastedAttributedString.length, length: 0)
        }
        
        open func resetTypingAttributes() {
            typingAttributes[.font] = appearance.textInputAppearance.labelAppearance.font
            typingAttributes[.foregroundColor] = appearance.textInputAppearance.labelAppearance.foregroundColor
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

public extension MessageInputViewController.InputTextView {
    enum FormatEvent {
        case bold, italic, monospace, strikethrough, underline
    }
}
