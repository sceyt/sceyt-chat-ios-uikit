//
//  CheckBoxView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension CheckBoxView: AppearanceProviding {
    
    public static var appearance = Appearance()
    
    public struct Appearance {
        public var uncheckedIcon: UIImage = .radio
        public var checkedIcon: UIImage = .radioSelected
        
        // Initializer with default values
        public init(
            uncheckedIcon: UIImage = .radio,
            checkedIcon: UIImage = .radioSelected
        ) {
            self.uncheckedIcon = uncheckedIcon
            self.checkedIcon = checkedIcon
        }
    }
}
