//
//  SelectedCellAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class SelectedCellAppearance<T: Formatting,
                                    A: AvatarRendering> {
    
    @Trackable<SelectedCellAppearance, LabelAppearance>
    public var labelAppearance: LabelAppearance
        
    @Trackable<SelectedCellAppearance, T>
    public var titleFormatter: T
    
    @Trackable<SelectedCellAppearance, UIImage>
    public var removeIcon: UIImage
    
    @Trackable<SelectedCellAppearance, A>
    public var avatarRenderer: A
    
    @Trackable<SelectedCellAppearance, AvatarAppearance>
    public var avatarAppearance: AvatarAppearance

    public init(
        labelAppearance: LabelAppearance,
        titleFormatter: T,
        removeIcon: UIImage,
        avatarRenderer: A,
        avatarAppearance: AvatarAppearance
    ) {
        self._labelAppearance = Trackable(value: labelAppearance)
        self._titleFormatter = Trackable(value: titleFormatter)
        self._removeIcon = Trackable(value: removeIcon)
        self._avatarRenderer = Trackable(value: avatarRenderer)
        self._avatarAppearance = Trackable(value: avatarAppearance)
    }
}
