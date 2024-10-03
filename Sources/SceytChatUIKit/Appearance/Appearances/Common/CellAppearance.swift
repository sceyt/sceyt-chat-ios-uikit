//
//  CellAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class CellAppearance<T: Formatting,
                            S: Formatting,
                            V: VisualProviding> {
    
    public var titleLabelAppearance: LabelAppearance
    public var subtitleLabelAppearance: LabelAppearance?
    public var titleFormatter: T
    public var subtitleFormatter: S
    public var visualProvider: V
    
    /// Initializes a new instance of `CellAppearance` with the provided parameters.
    ///
    /// - Parameters:
    ///   - titleLabelAppearance: The appearance settings for the title label.
    ///   - subtitleLabelAppearance: The appearance settings for the subtitle label.
    ///   - titleFormatter: The formatter to use for the title text.
    ///   - subtitleFormatter: The formatter to use for the subtitle text.
    ///   - visualProvider: The provider for visuals.
    public init(
        titleLabelAppearance: LabelAppearance,
        subtitleLabelAppearance: LabelAppearance?,
        titleFormatter: T,
        subtitleFormatter: S,
        visualProvider: V
    ) {
        self.titleLabelAppearance = titleLabelAppearance
        self.subtitleLabelAppearance = subtitleLabelAppearance
        self.titleFormatter = titleFormatter
        self.subtitleFormatter = subtitleFormatter
        self.visualProvider = visualProvider
    }
}


