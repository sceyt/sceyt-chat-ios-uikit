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
    public var selectedIcon: UIImage
    public var unselectedIcon: UIImage
    
    /// Initializes a new instance of `SelectableCellAppearance` with the provided parameters.
    ///
    /// - Parameters:
    ///   - titleLabelAppearance: The appearance settings for the title label.
    ///   - subtitleLabelAppearance: The appearance settings for the subtitle label.
    ///   - titleFormatter: The formatter to use for the title text.
    ///   - subtitleFormatter: The formatter to use for the subtitle text.
    ///   - avatarProvider: The provider for avatar visuals.
    ///   - selectedIcon: The image to use when the item is selected.
    ///   - unselectedIcon: The image to use when the item is unselected.
    public init(
        titleLabelAppearance: LabelAppearance,
        subtitleLabelAppearance: LabelAppearance,
        titleFormatter: T,
        subtitleFormatter: S,
        avatarProvider: A,
        selectedIcon: UIImage,
        unselectedIcon: UIImage
    ) {
        self.selectedIcon = selectedIcon
        self.unselectedIcon = unselectedIcon
        
        super.init(
            titleLabelAppearance: titleLabelAppearance,
            subtitleLabelAppearance: subtitleLabelAppearance,
            titleFormatter: titleFormatter,
            subtitleFormatter: subtitleFormatter,
            avatarProvider: avatarProvider
        )
    }
}
