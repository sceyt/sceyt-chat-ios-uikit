//
//  SelectableItemAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class SelectableCellAppearance<T: Formatting,
                                      S: Formatting,
                                      A: VisualProviding>: CellAppearance<T, S, A> {
    @Trackable<Appearance, UIImage>
    public var selectedIcon: UIImage
    
    @Trackable<Appearance, UIImage>
    public var unselectedIcon: UIImage

    /// Initializes a new instance of `SelectableCellAppearance` with the provided parameters.
    ///
    /// - Parameters:
    ///   - titleLabelAppearance: The appearance settings for the title label.
    ///   - subtitleLabelAppearance: The appearance settings for the subtitle label.
    ///   - titleFormatter: The formatter to use for the title text.
    ///   - subtitleFormatter: The formatter to use for the subtitle text.
    ///   - visualProvider: The provider for avatar visuals.
    ///   - selectedIcon: The image to use when the item is selected.
    ///   - unselectedIcon: The image to use when the item is unselected.
    public init(
        titleLabelAppearance: LabelAppearance,
        subtitleLabelAppearance: LabelAppearance,
        titleFormatter: T,
        subtitleFormatter: S,
        visualProvider: A,
        selectedIcon: UIImage,
        unselectedIcon: UIImage
    ) {
        self._selectedIcon = Trackable(value: selectedIcon)
        self._unselectedIcon = Trackable(value: unselectedIcon)

        super.init(
            titleLabelAppearance: titleLabelAppearance,
            subtitleLabelAppearance: subtitleLabelAppearance,
            titleFormatter: titleFormatter,
            subtitleFormatter: subtitleFormatter,
            visualProvider: visualProvider
        )
    }
}
