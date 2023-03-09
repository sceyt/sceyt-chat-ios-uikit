//
//  TextSizeCounter.swift
//  SceytChatUIKit
//  Copyright © 2020 Varmtech LLC. All rights reserved.
//

import UIKit

public struct TextSizeCounter {

    public let textContainer: NSTextContainer
    public let layoutManager: NSLayoutManager
    public let textStorage: NSTextStorage

    public mutating func calculateSize(of text: NSAttributedString,
                                       restrictingWidth: CGFloat = 500.0,
                                       maximumNumberOfLines: Int = 0) -> Size {
        guard !text.isEmpty else { return .init(textSize: .zero, lastCharRect: .null) }
        let newSize = CGSize(width: restrictingWidth, height: CGFloat(Float.greatestFiniteMagnitude))
        if textContainer.size != newSize {
            textContainer.size = newSize
        }
        if textContainer.maximumNumberOfLines != maximumNumberOfLines {
            textContainer.maximumNumberOfLines = maximumNumberOfLines
        }
        
        textStorage.setAttributedString(text)
        layoutManager.ensureLayout(for: textContainer)
        let lastGlyphIndex = layoutManager.glyphIndexForCharacter(at: text.length - 1)
        let rect = layoutManager.lineFragmentUsedRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
        return .init(textSize: layoutManager.usedRect(for: textContainer).size.ceil(), lastCharRect: rect)
    }

    public init() {
        textContainer = .init()
        layoutManager = .init()
        textStorage = .init()
        textContainer.lineFragmentPadding = 0
        layoutManager.usesFontLeading = false
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
    }
    
    public init(
        textContainer: NSTextContainer,
        layoutManager: NSLayoutManager,
        textStorage: NSTextStorage
    ) {
        self.textContainer = textContainer
        self.layoutManager = layoutManager
        self.textStorage = textStorage
    }
    
}

public extension TextSizeCounter {

    struct Size {
        public let textSize: CGSize
        public let lastCharRect: CGRect
    }
}

fileprivate extension CGSize {
    func ceil() -> CGSize {
        return CGSize(width: Darwin.ceil(width), height: Darwin.ceil(height))
    }
}
