//
//  InputLinkPreviewAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

public class InputLinkPreviewAppearance: AppearanceProviding {
    
    public var appearance: InputLinkPreviewAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: InputLinkPreviewAppearance?
    
    public static var appearance = InputLinkPreviewAppearance(
        backgroundColor: .clear,
        titleLabelAppearance: LabelAppearance(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(13)
        ),
        descriptionLabelAppearance: LabelAppearance(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        highlightedLinkBackgroundColor: .clear,
        placeholderIcon: .link
    )
    
    @Trackable<InputLinkPreviewAppearance, UIColor>
    public var backgroundColor: UIColor
    
    @Trackable<InputLinkPreviewAppearance, LabelAppearance>
    public var titleLabelAppearance: LabelAppearance
    
    @Trackable<InputLinkPreviewAppearance, LabelAppearance>
    public var descriptionLabelAppearance: LabelAppearance
    
    @Trackable<InputLinkPreviewAppearance, UIColor>
    public var highlightedLinkBackgroundColor: UIColor
    
    @Trackable<InputLinkPreviewAppearance, UIImage>
    public var placeholderIcon: UIImage
    
    public init(
        backgroundColor: UIColor,
        titleLabelAppearance: LabelAppearance,
        descriptionLabelAppearance: LabelAppearance,
        highlightedLinkBackgroundColor: UIColor,
        placeholderIcon: UIImage
    ) {
        self._backgroundColor = Trackable(value: backgroundColor)
        self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
        self._descriptionLabelAppearance = Trackable(value: descriptionLabelAppearance)
        self._highlightedLinkBackgroundColor = Trackable(value: highlightedLinkBackgroundColor)
        self._placeholderIcon = Trackable(value: placeholderIcon)
    }
    
    public init(
        reference: InputLinkPreviewAppearance,
        backgroundColor: UIColor? = nil,
        titleLabelAppearance: LabelAppearance? = nil,
        descriptionLabelAppearance: LabelAppearance? = nil,
        highlightedLinkBackgroundColor: UIColor? = nil,
        placeholderIcon: UIImage? = nil
    ) {
        self._backgroundColor = Trackable(reference: reference, referencePath: \.backgroundColor)
        self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
        self._descriptionLabelAppearance = Trackable(reference: reference, referencePath: \.descriptionLabelAppearance)
        self._highlightedLinkBackgroundColor = Trackable(reference: reference, referencePath: \.highlightedLinkBackgroundColor)
        self._placeholderIcon = Trackable(reference: reference, referencePath: \.placeholderIcon)
        
        if let backgroundColor { self.backgroundColor = backgroundColor }
        if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
        if let descriptionLabelAppearance { self.descriptionLabelAppearance = descriptionLabelAppearance }
        if let highlightedLinkBackgroundColor { self.highlightedLinkBackgroundColor = highlightedLinkBackgroundColor }
        if let placeholderIcon { self.placeholderIcon = placeholderIcon }
    }    
}
