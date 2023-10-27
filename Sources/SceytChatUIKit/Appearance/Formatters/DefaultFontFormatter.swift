//
//  DefaultFontFormatter.swift
//  SceytChatUIKit
//
//  Created by Duc on 27/09/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

open class DefaultFontFormatter: FontFormatter {
    open func isBold(_ font: UIFont) -> Bool {
        font.fontDescriptor.symbolicTraits.contains(.traitBold)
        || font.fontName == Fonts.bold.fontName
    }
    
    open func isItalic(_ font: UIFont) -> Bool {
        font.fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
    
    open func isMonospace(_ font: UIFont) -> Bool {
        font.fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
        || font.fontName == Fonts.monospace.fontName
    }
    
    open func toMonospace(_ original: UIFont) -> UIFont {
        var result = Fonts.monospace.withSize(original.pointSize)
        if isBold(original) {
            result = result.with(traits: .traitBold)
        }
        if isItalic(original) {
            result = result.with(traits: .traitItalic)
        }
        return result
    }
    
    open func toBold(_ original: UIFont) -> UIFont {
        var result = Fonts.bold.withSize(original.pointSize)
        if isItalic(original) {
            result = result.with(traits: .traitItalic)
        }
        if isMonospace(original) {
            result = toMonospace(result)
        }
        return result
    }
    
    open func toItalic(_ original: UIFont) -> UIFont {
        return original.with(traits: .traitItalic, pointSize: original.pointSize)
    }
}
