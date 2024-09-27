//
//  ItemAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class ItemAppearance<T: Formatting,
                            S: Formatting,
                            A: VisualProviding> {
    
    public var titleLabelAppearance: LabelAppearance
    public var subtitleLabelAppearance: LabelAppearance?
    public var titleFormatter: T
    public var subtitleFormatter: S
    public var avatarProvider: A
    
    /// Initializes a new instance of `ItemAppearance` with the provided parameters.
    ///
    /// - Parameters:
    ///   - titleLabelAppearance: The appearance settings for the title label.
    ///   - subtitleLabelAppearance: The appearance settings for the subtitle label.
    ///   - titleFormatter: The formatter to use for the title text.
    ///   - subtitleFormatter: The formatter to use for the subtitle text.
    ///   - avatarProvider: The provider for avatar visuals.
    public init(
        titleLabelAppearance: LabelAppearance,
        subtitleLabelAppearance: LabelAppearance?,
        titleFormatter: T,
        subtitleFormatter: S,
        avatarProvider: A
    ) {
        self.titleLabelAppearance = titleLabelAppearance
        self.subtitleLabelAppearance = subtitleLabelAppearance
        self.titleFormatter = titleFormatter
        self.subtitleFormatter = subtitleFormatter
        self.avatarProvider = avatarProvider
    }
}
