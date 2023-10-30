//
//  TextSizeMeasure.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 29.09.22.
//  Copyright © 2022 Sceyt LLC. All rights reserved.
//

import UIKit

public extension TextSizeMeasure {

    struct Size {
        public let textSize: CGSize
        public let lastCharRect: CGRect
    }
    
    struct Config {
        public var restrictingWidth: CGFloat
        public var maximumNumberOfLines: Int
        public var font: UIFont?
        public var lineBreakMode: NSLineBreakMode
        public var lastFragmentUsedRect: Bool
        public init(restrictingWidth: CGFloat = MessageLayoutModel.defaults.messageWidth,
                    maximumNumberOfLines: Int = 0,
                    font: UIFont? = nil,
                    lineBreakMode: NSLineBreakMode = NSLineBreakMode.byWordWrapping,
                    lastFragmentUsedRect: Bool = true) {
            self.restrictingWidth = restrictingWidth
            self.maximumNumberOfLines = maximumNumberOfLines
            self.font = font
            self.lineBreakMode = lineBreakMode
            self.lastFragmentUsedRect = lastFragmentUsedRect
        }
    }
}

fileprivate extension CGSize {
    func ceil() -> CGSize {
        return CGSize(width: Darwin.ceil(width), height: Darwin.ceil(height))
    }
}

open class TextSizeMeasure {
   
    public static func calculateSize(of text: NSAttributedString,
                              config: Config = .init()) -> Size {
        guard !text.isEmpty else { return .init(textSize: .zero, lastCharRect: .zero) }
        let textContainer = NSTextContainer(size: CGSize(width: config.restrictingWidth, height: .greatestFiniteMagnitude))
        textContainer.maximumNumberOfLines = config.maximumNumberOfLines
        textContainer.lineBreakMode = config.lineBreakMode
        textContainer.lineFragmentPadding = 0
        let size = textContainer.size(for: text, font: config.font, lastFragmentUsedRect: config.lastFragmentUsedRect)
        return .init(textSize: size.0, lastCharRect: size.1)
    }
    
    public static func calculateSize(of text: String,
                              config: Config = .init()) -> Size {
        
        let attributedString = NSAttributedString(string: text)
        return calculateSize(of: attributedString, config: config)
    }
}

internal extension NSTextContainer {
    
    func size(for text: NSAttributedString,
                              font: UIFont?,
              lastFragmentUsedRect: Bool
    ) -> (CGSize, CGRect) {
        guard !text.isEmpty else { return (.zero, .zero) }
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(self)
        let attributedString: NSAttributedString
        if let font {
            let mutableAttributedString = NSMutableAttributedString(attributedString: text)
            mutableAttributedString.addAttributeToEntireString(.font, value: font)
            attributedString = mutableAttributedString
        } else {
            attributedString = text
        }
        
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        textStorage.setAttributedString(attributedString)
        let size = withExtendedLifetime(textStorage) {
            let size = layoutManager.usedRect(for: self).size.ceil()
            var rect: CGRect = .zero
            
            if lastFragmentUsedRect {
                let glyphRange = layoutManager.glyphRange(for: self)
                if glyphRange.location != NSNotFound,
                    glyphRange.length > 0 {
                    let lastGlyphIndex = layoutManager.glyphIndexForCharacter(at: attributedString.length - 1)
                    rect = layoutManager.lineFragmentUsedRect(forGlyphAt: lastGlyphIndex,
                                                              effectiveRange: nil,
                                                              withoutAdditionalLayout: true)
                }
            }
            return (size, rect)
        }
        return size
    }
    
    func characterIndex(
        of location: CGPoint,
        textStorage: NSTextStorage,
        layoutManager: NSLayoutManager
    ) -> Int? {
        guard textStorage.length > 0
        else { return nil }

        let glyphRange = layoutManager.glyphRange(for: self)
        let boundingRect = layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: self
        )
        guard boundingRect.contains(location)
        else { return nil }

        let glyphIndex = layoutManager.glyphIndex(
            for: location,
            in: self
        )
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: self
        )
        guard glyphRect.contains(location)
        else { return nil }
        return layoutManager.characterIndexForGlyph(at: glyphIndex)
    }
}
