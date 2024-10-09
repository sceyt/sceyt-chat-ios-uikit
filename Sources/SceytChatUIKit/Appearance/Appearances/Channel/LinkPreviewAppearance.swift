//
//  LinkPreviewAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

public class LinkPreviewAppearance: AppearanceProviding {
    
    public var appearance: LinkPreviewAppearance {
        parentAppearance ?? Self.appearance
    }
    
    public var parentAppearance: LinkPreviewAppearance?
    
    public static var appearance = LinkPreviewAppearance(
        titleLabelAppearance: .init(
            foregroundColor: .accent,
            font: Fonts.semiBold.withSize(13)
        ),
        descriptionLabelAppearance: .init(
            foregroundColor: .secondaryText,
            font: Fonts.regular.withSize(13)
        ),
        highlightedLinkBackgroundColor: .clear,
        placeholderIcon: .link
    )
    
    @Trackable<LinkPreviewAppearance, LabelAppearance>
    public var titleLabelAppearance: LabelAppearance
    
    @Trackable<LinkPreviewAppearance, LabelAppearance>
    public var descriptionLabelAppearance: LabelAppearance
    
    @Trackable<LinkPreviewAppearance, UIColor>
    public var highlightedLinkBackgroundColor: UIColor
    
    @Trackable<LinkPreviewAppearance, UIImage?>
    public var placeholderIcon: UIImage?
    
    // Initializer with default values
    public init(
        titleLabelAppearance: LabelAppearance,
        descriptionLabelAppearance: LabelAppearance,
        highlightedLinkBackgroundColor: UIColor,
        placeholderIcon: UIImage?
    ) {
        self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
        self._descriptionLabelAppearance = Trackable(value: descriptionLabelAppearance)
        self._highlightedLinkBackgroundColor = Trackable(value: highlightedLinkBackgroundColor)
        self._placeholderIcon = Trackable(value: placeholderIcon)
    }
    
    public init(
        reference: LinkPreviewAppearance,
        titleLabelAppearance: LabelAppearance? = nil,
        descriptionLabelAppearance: LabelAppearance? = nil,
        highlightedLinkBackgroundColor: UIColor? = nil,
        placeholderIcon: UIImage? = nil
    ) {
        self._titleLabelAppearance = Trackable(reference: reference, referencePath: \.titleLabelAppearance)
        self._descriptionLabelAppearance = Trackable(reference: reference, referencePath: \.descriptionLabelAppearance)
        self._highlightedLinkBackgroundColor = Trackable(reference: reference, referencePath: \.highlightedLinkBackgroundColor)
        self._placeholderIcon = Trackable(reference: reference, referencePath: \.placeholderIcon)
        
        if let titleLabelAppearance { self.titleLabelAppearance = titleLabelAppearance }
        if let descriptionLabelAppearance { self.descriptionLabelAppearance = descriptionLabelAppearance }
        if let highlightedLinkBackgroundColor { self.highlightedLinkBackgroundColor = highlightedLinkBackgroundColor }
        if let placeholderIcon { self.placeholderIcon = placeholderIcon }
    }
}
