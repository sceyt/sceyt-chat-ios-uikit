//
//  LabelAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public struct LabelAppearance {
    @Trackable<LabelAppearance, UIColor>
    public var foregroundColor: UIColor
    
    @Trackable<LabelAppearance, UIFont>
    public var font: UIFont
    
    @Trackable<LabelAppearance, UIColor>
    public var backgroundColor: UIColor

    /// The un-scaled font as originally configured (before `asDynamic()`).
    ///
    /// `font` is scaled to the content size category that was current when this
    /// appearance was created, and that value is frozen. `baseFont` keeps the
    /// original so callers can re-derive a size for a *different* category later
    /// (e.g. recomputing a fixed row height after a Large Text change) via
    /// `baseFont.asDynamic(compatibleWith:)`.
    public let baseFont: UIFont

    // Initializer with default values
    public init(
        foregroundColor: UIColor,
        font: UIFont,
        backgroundColor: UIColor = .clear
    ) {
        self._foregroundColor = Trackable(value: foregroundColor)
        self._font = Trackable(value: font.asDynamic())
        self._backgroundColor = Trackable(value: backgroundColor)
        self.baseFont = font
    }

    // Convenience initializer for optional values
    public init(
        reference: LabelAppearance,
        foregroundColor: UIColor? = nil,
        font: UIFont? = nil,
        backgroundColor: UIColor? = nil
    ) {
        self._foregroundColor = Trackable(reference: reference, referencePath: \.foregroundColor)
        self._font = Trackable(reference: reference, referencePath: \.font)
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        self.baseFont = font ?? reference.baseFont

        if let foregroundColor { self.foregroundColor = foregroundColor }
        if let font { self.font = font.asDynamic() }
        if let backgroundColor { self.backgroundColor = backgroundColor }
    }

    /// Creates an appearance with an explicit, already-scaled `font` while
    /// keeping a separate un-scaled `baseFont` for later re-derivation.
    ///
    /// Unlike the primary initializer this does *not* run `asDynamic()` on the
    /// font again, so callers can pass a font already scaled for a specific
    /// trait collection (see `rescaledFont(compatibleWith:)`).
    public init(
        foregroundColor: UIColor,
        scaledFont: UIFont,
        baseFont: UIFont,
        backgroundColor: UIColor = .clear
    ) {
        self._foregroundColor = Trackable(value: foregroundColor)
        self._font = Trackable(value: scaledFont)
        self._backgroundColor = Trackable(value: backgroundColor)
        self.baseFont = baseFont
    }
}

extension LabelAppearance {
    /// Returns a value-isolated copy whose `font` is re-derived from `baseFont`
    /// for the given trait collection's content size category.
    ///
    /// `font` is otherwise frozen at the category that was current when the
    /// appearance was created (see `baseFont`). Use this after a Dynamic Type /
    /// Large Text change to rebuild attributed strings with correctly-sized
    /// fonts: an `NSAttributedString`'s embedded fonts are *not* re-scaled by a
    /// label's `adjustsFontForContentSizeCategory` when the string is assigned
    /// to a reused cell, only when a live category-change notification arrives
    /// while the label is on screen.
    ///
    /// The returned copy has its own backing storage, so it never mutates the
    /// (reference-type `Trackable`-backed) appearance it was derived from.
    public func rescaledFont(compatibleWith traitCollection: UITraitCollection?) -> LabelAppearance {
        LabelAppearance(
            foregroundColor: foregroundColor,
            scaledFont: baseFont.asDynamic(compatibleWith: traitCollection),
            baseFont: baseFont,
            backgroundColor: backgroundColor
        )
    }
}

public struct OptionalLabelAppearance {
    @Trackable<OptionalLabelAppearance, UIColor?>
    public var foregroundColor: UIColor?
    
    @Trackable<OptionalLabelAppearance, UIFont>
    public var font: UIFont
    
    @Trackable<OptionalLabelAppearance, UIColor>
    public var backgroundColor: UIColor
    
    // Initializer with default values
    public init(
        foregroundColor: UIColor?,
        font: UIFont,
        backgroundColor: UIColor = .clear
    ) {
        self._foregroundColor = Trackable(value: foregroundColor)
        self._font = Trackable(value: font.asDynamic())
        self._backgroundColor = Trackable(value: backgroundColor)
    }
    
    // Convenience initializer for optional values
    public init(
        reference: OptionalLabelAppearance,
        foregroundColor: UIColor? = nil,
        font: UIFont? = nil,
        backgroundColor: UIColor? = nil
    ) {
        self._foregroundColor = Trackable(reference: reference, referencePath: \.foregroundColor)
        self._font = Trackable(reference: reference, referencePath: \.font)
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        
        if let foregroundColor { self.foregroundColor = foregroundColor }
        if let font { self.font = font.asDynamic() }
        if let backgroundColor { self.backgroundColor = backgroundColor }
    }
}

extension UIFont {
    /// Returns a Dynamic Type aware copy of the font.
    ///
    /// - Parameter traitCollection: The trait collection to scale for. Pass the
    ///   current view's `traitCollection` to recompute sizes after a Large Text
    ///   change; `nil` uses the current environment (`UITraitCollection.current`).
    public func asDynamic(textStyle: UIFont.TextStyle? = nil,
                          compatibleWith traitCollection: UITraitCollection? = nil) -> UIFont {
        let style = textStyle ?? UIFont.preferredTextStyle(for: pointSize)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: self, compatibleWith: traitCollection)
    }

    static func preferredTextStyle(for pointSize: CGFloat) -> UIFont.TextStyle {
        switch pointSize {
        case 0..<13: return .footnote
        case 13..<15: return .subheadline
        case 15..<17: return .body
        case 17..<20: return .headline
        default: return .title3
        }
    }
}
