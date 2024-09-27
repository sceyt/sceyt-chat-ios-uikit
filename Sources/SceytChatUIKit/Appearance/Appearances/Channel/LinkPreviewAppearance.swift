//
//  LinkPreviewAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 25.09.24.
//

import UIKit

public class LinkPreviewAppearance {
    public lazy var backgroundColor: UIColor = .clear
    public lazy var titleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                                  font: Fonts.semiBold.withSize(13))
    public lazy var descriptionLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                                        font: Fonts.regular.withSize(13))
    public lazy var highlightedLinkBackgroundColor: UIColor = .clear
    public lazy var placeholderIcon: UIImage = .link
    
    // Initializer with default values
    public init(
        backgroundColor: UIColor = .clear,
        titleLabelAppearance: LabelAppearance = .init(foregroundColor: .accent,
                                                      font: Fonts.semiBold.withSize(13)),
        descriptionLabelAppearance: LabelAppearance = .init(foregroundColor: .secondaryText,
                                                            font: Fonts.regular.withSize(13)),
        highlightedLinkBackgroundColor: UIColor = .clear,
        placeholderIcon: UIImage = .link
    ) {
        self.backgroundColor = backgroundColor
        self.titleLabelAppearance = titleLabelAppearance
        self.descriptionLabelAppearance = descriptionLabelAppearance
        self.highlightedLinkBackgroundColor = highlightedLinkBackgroundColor
        self.placeholderIcon = placeholderIcon
    }
}
