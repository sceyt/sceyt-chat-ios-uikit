//
//  EditChannelViewController+TextFieldCell+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 03.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension EditChannelViewController.TextFieldCell: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance: TextInputAppearance {
        public var separatorColor: UIColor = .border
        
        public init(separatorColor: UIColor = .border) {
            super.init(
                backgroundColor: .backgroundSections,
                labelAppearance: .init(
                    foregroundColor: .primaryText,
                    font: Fonts.regular.withSize(16)
                ),
                placeholderAppearance: .init(
                    foregroundColor: .secondaryText,
                    font: Fonts.regular.withSize(16)
                )
            )
            self.separatorColor = separatorColor
        }
    }
}
