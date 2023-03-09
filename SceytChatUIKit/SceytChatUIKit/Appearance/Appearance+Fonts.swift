//
//  Appearance+Fonts.swift
//  SceytChatUIKit
//

import UIKit

typealias Fonts = Appearance.Fonts

public extension Appearance {
    
    struct Fonts {
        static var defaultSize: CGFloat = 10
        
        public static var regular: UIFont  = UIFont.systemFont(ofSize: defaultSize, weight: .regular)
        public static var medium: UIFont = UIFont.systemFont(ofSize: defaultSize, weight: .medium)
        public static var semiBold: UIFont = UIFont.systemFont(ofSize: defaultSize, weight: .semibold)
        public static var bold: UIFont = UIFont.systemFont(ofSize: defaultSize, weight: .bold)
        public static var regularItalic: UIFont = UIFont.italicSystemFont(ofSize: defaultSize)
        
        public init() {}
    }
}

public extension UIFont {
    
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits, pointSize: CGFloat = .nan) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return .init(descriptor: descriptor, size: pointSize.isNaN ? self.pointSize : pointSize)
    }
    
    func bold(pointSize: CGFloat = .nan) -> UIFont {
        return withTraits(.traitBold, pointSize: pointSize)
    }
    
    func italic(pointSize: CGFloat = .nan) -> UIFont {
        return withTraits(.traitItalic, pointSize: pointSize)
    }
}
