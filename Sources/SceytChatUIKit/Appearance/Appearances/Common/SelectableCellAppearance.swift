//
//  SelectableItemAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class SelectableCellAppearance<T: Formatting,
                                      S: Formatting,
                                      A: AvatarRendering>: CellAppearance<T, S, A> {
    @Trackable<Appearance, CheckBoxView.Appearance>
    public var checkBoxAppearance: CheckBoxView.Appearance

    /// Initializes a new instance of `SelectableCellAppearance` with the provided parameters.
    ///
    /// - Parameters:
    ///   - titleLabelAppearance: The appearance settings for the title label.
    ///   - subtitleLabelAppearance: The appearance settings for the subtitle label.
    ///   - titleFormatter: The formatter to use for the title text.
    ///   - subtitleFormatter: The formatter to use for the subtitle text.
    ///   - visualProvider: The provider for avatar visuals.
    ///   - checkBoxAppearance: The check box appearance.
    public init(
        titleLabelAppearance: LabelAppearance,
        subtitleLabelAppearance: LabelAppearance,
        titleFormatter: T,
        subtitleFormatter: S,
        avatarRenderer: A,
        avatarAppearance: AvatarAppearance,
        checkBoxAppearance: CheckBoxView.Appearance
    ) {
        self._checkBoxAppearance = Trackable(value: checkBoxAppearance)

        super.init(
            titleLabelAppearance: titleLabelAppearance,
            subtitleLabelAppearance: subtitleLabelAppearance,
            titleFormatter: titleFormatter,
            subtitleFormatter: subtitleFormatter,
            avatarRenderer: avatarRenderer,
            avatarAppearance: avatarAppearance
        )
    }
}
