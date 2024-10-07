//
//  CheckBoxView+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 01.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension CheckBoxView: AppearanceProviding {
    
    public static var appearance = Appearance(
        uncheckedIcon: .radio,
        checkedIcon: .radioSelected
    )
    
    public struct Appearance {
        
        @Trackable<Appearance, UIImage>
        public var uncheckedIcon: UIImage
        
        @Trackable<Appearance, UIImage>
        public var checkedIcon: UIImage
        
        // Initializer with default values
        public init(
            uncheckedIcon: UIImage = .radio,
            checkedIcon: UIImage = .radioSelected
        ) {
            self._uncheckedIcon = Trackable(value: uncheckedIcon)
            self._checkedIcon = Trackable(value: checkedIcon)
        }
        
        // Convenience initializer
        public init(
            reference: CheckBoxView.Appearance,
            uncheckedIcon: UIImage? = nil,
            checkedIcon: UIImage? = nil
        ) {
            self._uncheckedIcon = Trackable(reference: reference, referencePath: \.uncheckedIcon)
            self._checkedIcon = Trackable(reference: reference, referencePath: \.checkedIcon)
            
            if let uncheckedIcon { self.uncheckedIcon = uncheckedIcon }
            if let checkedIcon { self.checkedIcon = checkedIcon }
        }
    }
}
