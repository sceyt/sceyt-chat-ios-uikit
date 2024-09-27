//
//  SelectedItemAppearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 24.09.24.
//

import UIKit

public class SelectedItemAppearance<T: Formatting,
                                     A: VisualProviding> {
    public var labelAppearance: LabelAppearance
    public var titleFormatter: T
    public var removeIcon: UIImage
    public var avatarProvider: A
    
    public init(labelAppearance: LabelAppearance,
                titleFormatter: T,
                removeIcon: UIImage,
                avatarProvider: A) {
        self.labelAppearance = labelAppearance
        self.titleFormatter = titleFormatter
        self.removeIcon = removeIcon
        self.avatarProvider = avatarProvider
    }
}
