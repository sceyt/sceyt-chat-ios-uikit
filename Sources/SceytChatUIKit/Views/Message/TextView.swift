//
//  TextView.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 09.08.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class TextLabel: View {
    
    private lazy var textStorage = NSTextStorage()
    private lazy var layoutManager = NSLayoutManager()
    private lazy var textContainer = NSTextContainer()
    
    open override var isFocused: Bool {
        false
    }

    open override var canBecomeFirstResponder: Bool {
        false
    }

    open override var canBecomeFocused: Bool {
        false
    }

    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }
   
    open override func setup() {
        super.setup()
        isExclusiveTouch = true
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        textContainer.lineFragmentPadding = 0
        isUserInteractionEnabled = true
        contentMode = .redraw
    }
    
    open override func setupAppearance() {
        super.setupAppearance()
        backgroundColor = .clear
    }
    
    open override func draw(_ rect: CGRect) {
        super.draw(rect)
        textContainer.size = bounds.size
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
    }
    
    open var attributedText: NSAttributedString? {
        didSet {
            updateTextStorage()
        }
    }
    
    
    fileprivate func updateTextStorage() {
        
        textContainer.size = bounds.size

        guard attributedText != nil, attributedText!.length > 0
        else {
            textStorage.setAttributedString(NSAttributedString())
            setNeedsDisplay()
            return
        }
        textStorage.setAttributedString(attributedText!)
        setNeedsDisplay()
    }
    
    public func indexForGesture(sender: UIGestureRecognizer) -> Int? {
        let location = sender.location(in: self)
        guard let characterIndex = textContainer
            .characterIndex(
                of: location,
                textStorage: textStorage,
                layoutManager: layoutManager)
        else { return nil }
        return characterIndex
    }
}
