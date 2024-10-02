//
//  SelectedCellAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class SelectedCellAppearance<T: Formatting,
                                     A: VisualProviding> {
    public var labelAppearance: LabelAppearance
    public var titleFormatter: T
    public var removeIcon: UIImage
    public var visualProvider: A
    
    public init(labelAppearance: LabelAppearance,
                titleFormatter: T,
                removeIcon: UIImage,
                visualProvider: A) {
        self.labelAppearance = labelAppearance
        self.titleFormatter = titleFormatter
        self.removeIcon = removeIcon
        self.visualProvider = visualProvider
    }
}
