//
//  ReactionPickerViewController+Appearance.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 27.09.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import UIKit

extension ReactionPickerViewController: AppearanceProviding {
    public static var appearance = Appearance()
    
    public class Appearance {
        public lazy var backgroundColor: UIColor = .backgroundSections
        public lazy var moreIcon: UIImage = .messageActionMoreReactions
        public lazy var selectedBackgroundColor: UIColor = .surface2
        
        // Initializer with default values
        public init(
            backgroundColor: UIColor = .backgroundSections,
            moreIcon: UIImage = .messageActionMoreReactions,
            selectedBackgroundColor: UIColor = .surface2
        ) {
            self.backgroundColor = backgroundColor
            self.moreIcon = moreIcon
            self.selectedBackgroundColor = selectedBackgroundColor
        }
    }
}
