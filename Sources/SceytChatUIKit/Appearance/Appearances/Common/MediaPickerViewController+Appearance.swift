//
//  MediaPickerViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension MediaPickerViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var backgroundColor: UIColor
        public var titleText: String
        public var confirmButtonAppearance: ButtonAppearance
        public var countLabelAppearance: LabelAppearance
        public var cellAppearance: MediaPickerViewController.MediaCell.Appearance
        
        public init(
            backgroundColor: UIColor = .background,
            titleText: String = L10n.ImagePicker.title,
            confirmButtonAppearance: ButtonAppearance = .init(
                labelAppearance: .init(
                    foregroundColor: .onPrimary,
                    font: Fonts.semiBold.withSize(16)
                ),
                backgroundColor: .accent,
                cornerRadius: 8
            ),
            countLabelAppearance: LabelAppearance = .init(
                foregroundColor: .accent,
                font: Fonts.semiBold.withSize(14),
                backgroundColor: .onPrimary
            ),
            cellAppearance: MediaPickerViewController.MediaCell.Appearance = SceytChatUIKit.Components.mediaPickerCell.appearance
        ) {
            self.backgroundColor = backgroundColor
            self.titleText = titleText
            self.confirmButtonAppearance = confirmButtonAppearance
            self.countLabelAppearance = countLabelAppearance
            self.cellAppearance = cellAppearance
        }
    }
}
