//
//  SelectedCellAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class SelectedCellAppearance<T: Formatting,
                                    V: VisualProviding> {
    
    @Trackable<SelectedCellAppearance, LabelAppearance>
    public var labelAppearance: LabelAppearance
        
    @Trackable<SelectedCellAppearance, T>
    public var titleFormatter: T
    
    @Trackable<SelectedCellAppearance, UIImage>
    public var removeIcon: UIImage
    
    @Trackable<SelectedCellAppearance, V>
    public var visualProvider: V
    
    public init(
        labelAppearance: LabelAppearance,
        titleFormatter: T,
        removeIcon: UIImage,
        visualProvider: V
    ) {
        self._labelAppearance = Trackable(value: labelAppearance)
        self._titleFormatter = Trackable(value: titleFormatter)
        self._removeIcon = Trackable(value: removeIcon)
        self._visualProvider = Trackable(value: visualProvider)
    }
}
