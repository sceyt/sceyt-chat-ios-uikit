//
//  CellAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

public class CellAppearance<T: Formatting,
                            S: Formatting,
                            A: AvatarRendering> {
    
    @Trackable<CellAppearance, LabelAppearance>
    public var titleLabelAppearance: LabelAppearance
    
    @Trackable<CellAppearance, LabelAppearance?>
    public var subtitleLabelAppearance: LabelAppearance?
    
    @Trackable<CellAppearance, T>
    public var titleFormatter: T
    
    @Trackable<CellAppearance, S>
    public var subtitleFormatter: S
    
    @Trackable<CellAppearance, A>
    public var avatarRenderer: A
    
    @Trackable<CellAppearance, AvatarAppearance>
    public var avatarAppearance: AvatarAppearance

    /// Initializes a new instance of `CellAppearance` with the provided parameters.
    ///
    /// - Parameters:
    ///   - titleLabelAppearance: The appearance settings for the title label.
    ///   - subtitleLabelAppearance: The appearance settings for the subtitle label.
    ///   - titleFormatter: The formatter to use for the title text.
    ///   - subtitleFormatter: The formatter to use for the subtitle text.
    ///   - avatarRenderer: The avatar renderer.
    ///   - avatarAppearance: The appearance for avatar renderer.
    public init(
        titleLabelAppearance: LabelAppearance,
        subtitleLabelAppearance: LabelAppearance?,
        titleFormatter: T,
        subtitleFormatter: S,
        avatarRenderer: A,
        avatarAppearance: AvatarAppearance
    ) {
        self._titleLabelAppearance = Trackable(value: titleLabelAppearance)
        self._subtitleLabelAppearance = Trackable(value: subtitleLabelAppearance)
        self._titleFormatter = Trackable(value: titleFormatter)
        self._subtitleFormatter = Trackable(value: subtitleFormatter)
        self._avatarRenderer = Trackable(value: avatarRenderer)
        self._avatarAppearance = Trackable(value: avatarAppearance)
    }
}
