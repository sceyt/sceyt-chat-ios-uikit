//
//  Appearance+Fonts.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

typealias Fonts = Appearance.Fonts

public extension Appearance {
    public struct Fonts {
        public static var defaultSize: CGFloat = 10
        
        public static var regular: UIFont = UIFont.systemFont(ofSize: defaultSize, weight: .regular)
        public static var semiBold: UIFont = UIFont.systemFont(ofSize: defaultSize, weight: .semibold)
        public static var bold: UIFont = UIFont.systemFont(ofSize: defaultSize, weight: .bold)
        public static var monospace: UIFont = UIFont.monospacedSystemFont(ofSize: defaultSize, weight: .regular)
        
        public init() {}
    }
}

public extension UIFont {
    func with(traits: UIFontDescriptor.SymbolicTraits, pointSize: CGFloat = .nan) -> UIFont {
        var symbolicTraits = fontDescriptor.symbolicTraits
        symbolicTraits.insert(traits)
        guard let descriptor = fontDescriptor.withSymbolicTraits(symbolicTraits) else { return self }
        return .init(descriptor: descriptor, size: pointSize.isNaN ? self.pointSize : pointSize)
    }
    
    var weight: UIFont.Weight {
        guard let weightNumber = traits[.weight] as? NSNumber else { return .regular }
        let weightRawValue = CGFloat(weightNumber.doubleValue)
        let weight = UIFont.Weight(rawValue: weightRawValue)
        return weight
    }
    
    private var traits: [UIFontDescriptor.TraitKey: Any] {
        return fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        ?? [:]
    }
    
    var isBold: Bool {
        fontDescriptor.symbolicTraits.contains(.traitBold) || fontName == Fonts.bold.fontName
    }
    
    var isItalic: Bool {
        fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
    
    var isMonospace: Bool {
        fontDescriptor.symbolicTraits.contains(.traitMonoSpace) || fontName == Fonts.monospace.fontName
    }
    
    var monospace: UIFont {
        var result = Fonts.monospace.withSize(self.pointSize)
        if self.isBold {
            result = result.with(traits: .traitBold)
        }
        if self.isItalic {
            result = result.with(traits: .traitItalic)
        }
        return result
    }
    
    var bold: UIFont {
        var result = Fonts.bold.withSize(self.pointSize)
        if self.isItalic {
            result = result.with(traits: .traitItalic)
        }
        if self.isMonospace {
            result = result.monospace
        }
        return result
    }
    
    var italic: UIFont {
        return self.with(traits: .traitItalic, pointSize: self.pointSize)
    }
}
